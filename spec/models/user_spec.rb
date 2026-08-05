# spec/models/user_spec.rb
require "rails_helper"

RSpec.describe User, type: :model do
  let(:user) { build(:user) }

  it "is valid with required fields" do
    expect(user).to be_valid
  end

  it "requires first_name and last_name" do
    expect(build(:user, first_name: nil)).not_to be_valid
    expect(build(:user, last_name: nil)).not_to be_valid
  end

  it "requires unique email" do
    create(:user, email: "dup@example.com")
    expect(build(:user, email: "dup@example.com")).not_to be_valid
  end

  describe "default data on creation" do
    let(:new_user) { create(:user) }

    it "seeds default categories" do
      expect(new_user.categories).to be_present
    end

    it "does not auto-create example savings, debts, or goals" do
      expect(new_user.savings).to be_empty
      expect(new_user.debts).to be_empty
      expect(new_user.goals).to be_empty
    end
  end

  describe "#founding_member?" do
    it "covers accounts created before the cutoff" do
      travel_to(Time.utc(2026, 8, 4)) do
        expect(create(:user)).to be_founding_member
      end
    end

    it "covers an account created on the last eligible day in Mexico City" do
      # 2026-12-31 23:59 CST is 2027-01-01 05:59 UTC — still inside the offer.
      travel_to(Time.utc(2027, 1, 1, 5, 59)) do
        expect(create(:user)).to be_founding_member
      end
    end

    it "excludes accounts created after the cutoff" do
      travel_to(Time.utc(2027, 1, 1, 6)) do
        expect(create(:user)).not_to be_founding_member
      end
    end

    it "is false for an unsaved record rather than raising" do
      expect(build(:user)).not_to be_founding_member
    end
  end

  describe "password authentication" do
    let(:user) { create(:user, password: "pass123", password_confirmation: "pass123") }

    it "authenticates with correct password" do
      expect(user.authenticate("pass123")).to eq(user)
    end

    it "rejects wrong password" do
      expect(user.authenticate("wrong")).to be_falsey
    end
  end

  describe "#can_reset_password?" do
    context "for regular users" do
      let(:regular_user) { create(:user) }

      it "returns true" do
        expect(regular_user.can_reset_password?).to be true
      end
    end

    context "for OAuth users" do
      let(:oauth_user) { create(:user, provider: "google_oauth2", uid: "12345") }

      it "returns false" do
        expect(oauth_user.can_reset_password?).to be false
      end
    end
  end

  describe "#oauth_user?" do
    context "when provider and uid are present" do
      let(:user) { build(:user, provider: "google_oauth2", uid: "12345") }

      it "returns true" do
        expect(user.oauth_user?).to be true
      end
    end

    context "when provider is nil" do
      let(:user) { build(:user, provider: nil, uid: nil) }

      it "returns false" do
        expect(user.oauth_user?).to be false
      end
    end
  end

  describe "email confirmation" do
    describe "#confirmed?" do
      context "for regular users when not confirmed" do
        let(:user) { create(:user, confirmed_at: nil) }

        it "returns false" do
          expect(user.confirmed?).to be false
        end
      end

      context "for regular users when confirmed" do
        let(:user) { create(:user, confirmed_at: Time.current) }

        it "returns true" do
          expect(user.confirmed?).to be true
        end
      end

      context "for OAuth users" do
        let(:user) { create(:user, provider: "google_oauth2", uid: "12345", confirmed_at: nil) }

        it "returns true regardless of confirmed_at" do
          expect(user.confirmed?).to be true
        end
      end
    end

    describe "#confirm_email!" do
      let(:user) { create(:user, confirmed_at: nil) }

      it "sets confirmed_at to current time" do
        freeze_time do
          user.confirm_email!
          expect(user.confirmed_at).to eq(Time.current)
        end
      end
    end

    describe "#send_confirmation_email" do
      let(:user) { create(:user) }

      it "enqueues confirmation email" do
        expect {
          user.send_confirmation_email
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
          .with("ApplicationMailer", "confirmation_email", "deliver_now", { args: [user] })
      end
    end
  end

  describe ".find_or_create_from_oauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "12345",
        info: {
          email: "oauth@example.com",
          given_name: "John",
          family_name: "Doe",
          image: "http://example.com/avatar.jpg"
        }
      )
    end

    context "when creating a new OAuth user" do
      let(:user) { User.find_or_create_from_oauth(auth) }

      it "auto-confirms the user" do
        expect(user.confirmed_at).to be_present
        expect(user.confirmed?).to be true
      end
    end

    context "when linking OAuth to existing user" do
      let(:existing_user) { create(:user, email: "oauth@example.com", confirmed_at: nil) }
      let(:user) { User.find_or_create_from_oauth(auth) }

      before { existing_user }

      it "returns the existing user and confirms" do
        expect(existing_user.confirmed?).to be false
        expect(user.id).to eq(existing_user.id)
        expect(user.confirmed_at).to be_present
        expect(user.confirmed?).to be true
      end
    end
  end

  describe "#subscription_access_result" do
    context "when on trial" do
      let(:user) { create(:user) }

      it "returns allowed" do
        result = user.subscription_access_result
        expect(result[:allowed]).to be true
      end
    end

    context "when paid plan active (Pay::Subscription)" do
      let(:user) { create(:user).tap { |u| u.update_column(:trial_ends_at, nil) } }

      before { create(:pay_subscription, customer: create(:pay_customer, owner: user)) }

      it "returns allowed" do
        result = user.subscription_access_result
        expect(result[:allowed]).to be true
      end
    end

    context "when trial expired" do
      let(:user) { create(:user).tap { |u| u.update_columns(trial_ends_at: 1.day.ago) } }

      it "returns denied with reason trial_ended" do
        result = user.subscription_access_result
        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:trial_ended)
        expect(result[:message]).to be_present
      end
    end

    context "when past_due" do
      let(:user) { create(:user).tap { |u| u.update_column(:trial_ends_at, nil) } }

      before { create(:pay_subscription, :past_due, customer: create(:pay_customer, owner: user)) }

      it "returns denied with reason payment_failed" do
        result = user.subscription_access_result
        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:payment_failed)
        expect(result[:message]).to be_present
      end
    end

    context "when subscription cancelled" do
      let(:user) { create(:user).tap { |u| u.update_column(:trial_ends_at, nil) } }

      before { create(:pay_subscription, :canceled, customer: create(:pay_customer, owner: user)) }

      it "returns denied with reason subscription_required" do
        result = user.subscription_access_result
        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:subscription_required)
        expect(result[:message]).to be_present
      end
    end
  end
end
