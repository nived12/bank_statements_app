require "rails_helper"

RSpec.describe BelvoSyncJob, type: :job do
  let(:user) { create(:user) }
  let(:belvo_link) { create(:belvo_link, user: user) }

  describe "#perform" do
    before do
      allow(BelvoSync::AccountsFetcher).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: 1, errors: nil)
      )
      allow(BelvoSync::TransactionsFetcher).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: { imported_count: 5 }, errors: nil)
      )
    end

    it "updates link to synced status on completion" do
      # Create a bank account so the job doesn't auto-disconnect
      create(:bank_account, user: user, belvo_link: belvo_link, belvo_account_id: "acc-123")

      described_class.perform_now(belvo_link.id)
      belvo_link.reload
      expect(belvo_link.sync_status).to eq("synced")
    end

    it "calls AccountsFetcher" do
      create(:bank_account, user: user, belvo_link: belvo_link, belvo_account_id: "acc-123")

      expect(BelvoSync::AccountsFetcher).to receive(:call).with(belvo_link: belvo_link)
      described_class.perform_now(belvo_link.id)
    end

    it "updates last_synced_at on completion" do
      create(:bank_account, user: user, belvo_link: belvo_link, belvo_account_id: "acc-123")

      described_class.perform_now(belvo_link.id)
      belvo_link.reload
      expect(belvo_link.last_synced_at).to be_present
    end

    context "when account fetch fails" do
      before do
        allow(BelvoSync::AccountsFetcher).to receive(:call).and_return(
          ApplicationService::Response.new(success: false, payload: nil, errors: nil)
        )
      end

      it "sets error status" do
        described_class.perform_now(belvo_link.id)
        belvo_link.reload
        expect(belvo_link.sync_status).to eq("error")
      end
    end

    context "when no bank accounts are created (orphan link)" do
      it "auto-disconnects the link" do
        expect(Belvo::LinkDestroyer).to receive(:call).with(belvo_link: belvo_link)
        described_class.perform_now(belvo_link.id)
      end

      it "does not attempt to sync transactions" do
        allow(Belvo::LinkDestroyer).to receive(:call).and_return(
          ApplicationService::Response.new(success: true, payload: belvo_link, errors: nil)
        )

        expect(BelvoSync::TransactionsFetcher).not_to receive(:call)
        described_class.perform_now(belvo_link.id)
      end
    end
  end

  it "is enqueued in the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
