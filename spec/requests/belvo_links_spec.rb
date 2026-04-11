require "rails_helper"

RSpec.describe "BelvoLinks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
  end

  describe "GET /belvo_links/new" do
    before do
      allow_any_instance_of(User).to receive(:can_connect_bank?).and_return(true)
      allow(Belvo::AccessTokenGenerator).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: "test_token", errors: nil)
      )
    end

    it "returns success when user can connect" do
      get "/belvo_links/new"
      expect(response).to have_http_status(:success)
    end

    context "when user has reached link limit" do
      before do
        allow_any_instance_of(User).to receive(:can_connect_bank?).and_return(false)
      end

      it "redirects to bank accounts" do
        get "/belvo_links/new"
        expect(response).to redirect_to(bank_accounts_path)
      end
    end

    context "when user has no subscription" do
      before do
        allow_any_instance_of(User).to receive(:subscription_access_result).and_return(
          { allowed: false, reason: :subscription_required, message: "Upgrade required" }
        )
      end

      it "redirects to bank accounts" do
        get "/belvo_links/new"
        expect(response).to redirect_to(bank_accounts_path)
      end
    end
  end

  describe "POST /belvo_links" do
    before do
      allow_any_instance_of(User).to receive(:subscription_access_result).and_return({ allowed: true })
      allow(Belvo::LinkCreator).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: create(:belvo_link, user: user), errors: nil)
      )
    end

    it "creates a link and redirects" do
      post "/belvo_links", params: { link_id: SecureRandom.uuid, institution: "bbva_mx_retail" }
      expect(response).to redirect_to(bank_accounts_path)
    end

    context "when creation fails" do
      before do
        allow(Belvo::LinkCreator).to receive(:call).and_return(
          ApplicationService::Response.new(success: false, payload: nil, errors: nil)
        )
      end

      it "redirects with alert" do
        post "/belvo_links", params: { link_id: SecureRandom.uuid, institution: "bbva_mx_retail" }
        expect(response).to redirect_to(bank_accounts_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /belvo_links/:id" do
    let(:belvo_link) { create(:belvo_link, user: user) }

    before do
      allow_any_instance_of(User).to receive(:subscription_access_result).and_return({ allowed: true })
      allow(Belvo::LinkDestroyer).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: belvo_link, errors: nil)
      )
    end

    it "destroys the link and redirects" do
      delete "/belvo_links/#{belvo_link.id}"
      expect(response).to redirect_to(bank_accounts_path)
    end
  end

  describe "POST /belvo_links/:id/sync" do
    let(:belvo_link) { create(:belvo_link, user: user) }

    before do
      allow_any_instance_of(User).to receive(:subscription_access_result).and_return({ allowed: true })
    end

    it "enqueues a sync job and redirects" do
      expect {
        post "/belvo_links/#{belvo_link.id}/sync"
      }.to have_enqueued_job(BelvoSyncJob).with(belvo_link.id)

      expect(response).to redirect_to(bank_accounts_path)
    end
  end
end
