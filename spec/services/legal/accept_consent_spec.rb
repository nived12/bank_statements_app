# frozen_string_literal: true

require "rails_helper"

RSpec.describe Legal::AcceptConsent do
  let(:user) { create(:user, :confirmed, :not_consented) }

  describe ".call" do
    subject(:result) { described_class.call(user: user, ip_address: "1.2.3.4", user_agent: "TestAgent/1.0") }

    it "returns success" do
      expect(result).to be_success
    end

    it "creates one audit record per required document" do
      expect { result }.to change(LegalConsent, :count).by(LegalDocument::REQUIRED_DOCUMENTS.length)
    end

    it "stores email on each audit record for post-deletion traceability" do
      result
      expect(LegalConsent.where(email: user.email).count).to eq(LegalDocument::REQUIRED_DOCUMENTS.length)
    end

    it "stores ip_address and user_agent on each audit record" do
      result
      record = LegalConsent.find_by(user: user, document_type: LegalDocument::REQUIRED_DOCUMENTS.first)
      expect(record.ip_address).to eq("1.2.3.4")
      expect(record.user_agent).to eq("TestAgent/1.0")
    end

    it "all audit records share the same accepted_at timestamp" do
      result
      timestamps = LegalConsent.where(user: user).pluck(:accepted_at).map(&:to_i)
      expect(timestamps.uniq.length).to eq(1)
    end

    it "returned accepted_at matches the stored timestamp" do
      result
      stored = LegalConsent.find_by(user: user, document_type: LegalDocument::REQUIRED_DOCUMENTS.first).accepted_at
      expect(result.payload[:accepted_at].to_i).to eq(stored.to_i)
    end

    it "updates user consent timestamps" do
      result
      user.reload
      expect(user.terms_accepted_at).to be_present
      expect(user.privacy_accepted_at).to be_present
      expect(user.legal_version_accepted).to eq(LegalDocument::CURRENT_VERSION)
    end

    it "returns the accepted version" do
      expect(result.payload[:version]).to eq(LegalDocument::CURRENT_VERSION)
    end

    context "when user is blank" do
      subject(:result) { described_class.call(user: nil) }

      it "returns failure" do
        expect(result).not_to be_success
      end

      it "creates no audit records" do
        expect { result }.not_to change(LegalConsent, :count)
      end
    end
  end
end
