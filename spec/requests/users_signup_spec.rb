# spec/requests/users_signup_spec.rb
require "rails_helper"

RSpec.describe "User signup", type: :request do
  let(:params) do
    {
      user: {
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        password: "secret123",
        password_confirmation: "secret123"
      }
    }
  end

  it "creates an account and signs in" do
    expect {
      post "/users", params: { user: { first_name: "Ana", last_name: "Lopez", email: "ana@example.com", password: "secret123", password_confirmation: "secret123" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to("/dashboard")
    follow_redirect!
    expect(response.body).to include("Welcome back, Ana Lopez")
  end
end
