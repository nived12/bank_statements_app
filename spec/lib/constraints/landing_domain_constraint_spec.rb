require "rails_helper"
require "constraints/landing_domain_constraint"

RSpec.describe Constraints::LandingDomainConstraint do
  subject(:constraint) { described_class.new }

  let(:request) { instance_double(ActionDispatch::Request, host: host, session: session) }
  let(:host) { "localhost" }
  let(:session) { {} }

  describe "#matches?" do
    context "in test/development (non-production)" do
      context "when user is not authenticated" do
        let(:session) { { user_id: nil } }

        it "returns true" do
          expect(constraint.matches?(request)).to be true
        end
      end

      context "when user is authenticated" do
        let(:session) { { user_id: 1 } }

        it "returns false" do
          expect(constraint.matches?(request)).to be false
        end
      end
    end

    context "in production" do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")) }

      context "when host is the landing domain" do
        let(:host) { "vitt.io" }

        it "returns true" do
          expect(constraint.matches?(request)).to be true
        end
      end

      context "when host is the app subdomain" do
        let(:host) { "app.vitt.io" }

        it "returns false" do
          expect(constraint.matches?(request)).to be false
        end
      end
    end
  end
end
