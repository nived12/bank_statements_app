require "rails_helper"

RSpec.describe Belvo::LinkCreator do
  let(:user) { create(:user) }
  let(:link_id) { SecureRandom.uuid }
  let(:institution) { "bbva_mx_retail" }

  before do
    # Stub subscription access to allow
    allow_any_instance_of(User).to receive(:can_connect_bank?).and_return(true)
  end

  describe ".call" do
    it "creates a BelvoLink record" do
      expect {
        described_class.call(user: user, link_id: link_id, institution: institution)
      }.to change(BelvoLink, :count).by(1)
    end

    it "enqueues a BelvoSyncJob" do
      expect {
        described_class.call(user: user, link_id: link_id, institution: institution)
      }.to have_enqueued_job(BelvoSyncJob)
    end

    it "returns a success response with the link" do
      result = described_class.call(user: user, link_id: link_id, institution: institution)
      expect(result).to be_success
      expect(result.payload).to be_a(BelvoLink)
      expect(result.payload.belvo_link_id).to eq(link_id)
    end

    context "when user cannot connect" do
      before do
        allow_any_instance_of(User).to receive(:can_connect_bank?).and_return(false)
      end

      it "returns failure" do
        result = described_class.call(user: user, link_id: link_id, institution: institution)
        expect(result).to be_failure
      end

      it "does not create a record" do
        expect {
          described_class.call(user: user, link_id: link_id, institution: institution)
        }.not_to change(BelvoLink, :count)
      end
    end
  end
end
