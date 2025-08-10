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
end
