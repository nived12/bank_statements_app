# spec/requests/users_signup_spec.rb
require "rails_helper"

RSpec.describe "User signup", type: :request do
  it "creates an account and signs in" do
    expect {
      post "/es/users", params: { user: { first_name: "Ana", last_name: "Lopez", email: "ana@example.com", password: "secret123", password_confirmation: "secret123" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to("/es/dashboard")

    user = User.last
    expect(user.first_name).to eq("Ana")
    expect(user.last_name).to eq("Lopez")
    expect(user.email).to eq("ana@example.com")
  end
end
