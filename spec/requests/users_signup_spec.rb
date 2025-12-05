# spec/requests/users_signup_spec.rb
require "rails_helper"

RSpec.describe "User signup", type: :request do
  it "creates an account and sends confirmation email" do
    expect {
      post "/users", params: { user: { first_name: "Ana", last_name: "Lopez", email: "ana@example.com", password: "secret123", password_confirmation: "secret123" } }
    }.to change(User, :count).by(1)
      .and have_enqueued_job(ActionMailer::MailDeliveryJob)

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to eq(I18n.t("users.create.check_email"))

    user = User.last
    expect(user.first_name).to eq("Ana")
    expect(user.last_name).to eq("Lopez")
    expect(user.email).to eq("ana@example.com")
    expect(user.confirmed?).to be false
  end

  it "does not auto-login the user" do
    post "/users", params: { user: { first_name: "Ana", last_name: "Lopez", email: "ana@example.com", password: "secret123", password_confirmation: "secret123" } }

    expect(session[:user_id]).to be_nil
  end
end
