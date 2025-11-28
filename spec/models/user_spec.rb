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
end
