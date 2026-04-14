require "rails_helper"

RSpec.describe "Belvo::Webhooks", type: :request do
  let(:belvo_link) { create(:belvo_link) }

  describe "POST /belvo/webhooks" do
    context "transactions_available event" do
      it "enqueues a sync job" do
        expect {
          post "/belvo/webhooks", params: {
            event_type: "transactions_available",
            link_id: belvo_link.belvo_link_id
          }, as: :json
        }.to have_enqueued_job(BelvoSyncJob).with(belvo_link.id)

        expect(response).to have_http_status(:ok)
      end

      it "handles unknown link gracefully" do
        post "/belvo/webhooks", params: {
          event_type: "transactions_available",
          link_id: "unknown-link-id"
        }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "link_status_changed event" do
      it "updates link status" do
        post "/belvo/webhooks", params: {
          event_type: "link_status_changed",
          link_id: belvo_link.belvo_link_id,
          status: "token_required"
        }, as: :json

        expect(response).to have_http_status(:ok)
        belvo_link.reload
        expect(belvo_link.status).to eq("token_required")
      end
    end
  end
end
