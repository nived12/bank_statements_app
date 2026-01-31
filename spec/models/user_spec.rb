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

  it "authenticates with has_secure_password" do
    u = create(:user, password: "pass123", password_confirmation: "pass123")
    expect(u.authenticate("pass123")).to eq(u)
    expect(u.authenticate("wrong")).to be_falsey
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
    it "returns true when provider and uid are present" do
      user = build(:user, provider: "google_oauth2", uid: "12345")
      expect(user.oauth_user?).to be true
    end

    it "returns false when provider is nil" do
      user = build(:user, provider: nil, uid: nil)
      expect(user.oauth_user?).to be false
    end
  end

  describe "email confirmation" do
    describe "#confirmed?" do
      context "for regular users" do
        it "returns false when email is not confirmed" do
          user = create(:user, confirmed_at: nil)
          expect(user.confirmed?).to be false
        end

        it "returns true when email is confirmed" do
          user = create(:user, confirmed_at: Time.current)
          expect(user.confirmed?).to be true
        end
      end

      context "for OAuth users" do
        it "returns true regardless of confirmed_at" do
          user = create(:user, provider: "google_oauth2", uid: "12345", confirmed_at: nil)
          expect(user.confirmed?).to be true
        end
      end
    end

    describe "#confirm_email!" do
      it "sets confirmed_at to current time" do
        user = create(:user, confirmed_at: nil)

        freeze_time do
          user.confirm_email!
          expect(user.confirmed_at).to eq(Time.current)
        end
      end
    end

    describe "#send_confirmation_email" do
      it "enqueues confirmation email" do
        user = create(:user)

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

    it "auto-confirms OAuth users on creation" do
      user = User.find_or_create_from_oauth(auth)
      expect(user.confirmed_at).to be_present
      expect(user.confirmed?).to be true
    end

    it "auto-confirms existing users when linking OAuth" do
      existing_user = create(:user, email: "oauth@example.com", confirmed_at: nil)
      expect(existing_user.confirmed?).to be false

      user = User.find_or_create_from_oauth(auth)
      expect(user.id).to eq(existing_user.id)
      expect(user.confirmed_at).to be_present
      expect(user.confirmed?).to be true
    end
  end

  describe "#subscription_allows_access? and #subscription_access_result" do
    it "returns true when on trial" do
      user = create(:user)
      expect(user.trial_active?).to be true
      expect(user.subscription_allows_access?).to be true
      expect(user.subscription_access_result[:allowed]).to be true
    end

    it "returns true when paid plan active (Pay::Subscription)" do
      user = create(:user)
      user.update_column(:trial_ends_at, nil)
      pay_customer = Pay::Customer.create!(owner: user, processor: "stripe", processor_id: "manual_#{user.id}")
      Pay::Subscription.create!(
        customer: pay_customer,
        name: "pro",
        processor_id: "manual_sub_#{SecureRandom.hex(8)}",
        processor_plan: "pro",
        status: "active"
      )
      expect(user.subscription_allows_access?).to be true
      expect(user.subscription_access_result[:allowed]).to be true
    end

    it "returns false with reason trial_ended when trial expired" do
      user = create(:user)
      user.update_columns(trial_ends_at: 1.day.ago)
      expect(user.subscription_allows_access?).to be false
      result = user.subscription_access_result
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:trial_ended)
      expect(result[:message]).to be_present
    end

    it "returns false with reason payment_failed when past_due" do
      user = create(:user)
      user.update_column(:trial_ends_at, nil)
      pay_customer = Pay::Customer.create!(owner: user, processor: "stripe", processor_id: "manual_#{user.id}")
      Pay::Subscription.create!(
        customer: pay_customer,
        name: "pro",
        processor_id: "manual_sub_#{SecureRandom.hex(8)}",
        processor_plan: "pro",
        status: "past_due"
      )
      expect(user.subscription_allows_access?).to be false
      result = user.subscription_access_result
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:payment_failed)
      expect(result[:message]).to be_present
    end

    it "returns false with reason subscription_required when cancelled" do
      user = create(:user)
      user.update_column(:trial_ends_at, nil)
      pay_customer = Pay::Customer.create!(owner: user, processor: "stripe", processor_id: "manual_#{user.id}")
      Pay::Subscription.create!(
        customer: pay_customer,
        name: "pro",
        processor_id: "manual_sub_#{SecureRandom.hex(8)}",
        processor_plan: "pro",
        status: "canceled",
        ends_at: 1.day.ago
      )
      expect(user.subscription_allows_access?).to be false
      result = user.subscription_access_result
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:subscription_required)
      expect(result[:message]).to be_present
    end
  end
end
