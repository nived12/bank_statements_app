require "rails_helper"
require "sidekiq_web_auth"

# The gate itself is unit tested rather than driven through a request, because
# rendering the dashboard needs Redis and CI does not run one. The request spec
# covers only the rejection path, which never reaches the app.
RSpec.describe SidekiqWebAuth do
  # and_call_original before narrowing, for both [] and fetch — a bare .with
  # stub makes every other ENV read in the process return nil.
  def stub_credentials(user:, password:)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("SIDEKIQ_USER").and_return(user)
    allow(ENV).to receive(:[]).with("SIDEKIQ_PASSWORD").and_return(password)
  end

  describe ".authorized?" do
    before { stub_credentials(user: "ops", password: "correct-horse") }

    it "accepts the configured credentials" do
      expect(described_class.authorized?("ops", "correct-horse")).to be true
    end

    it "rejects a wrong password" do
      expect(described_class.authorized?("ops", "wrong")).to be false
    end

    it "rejects a wrong user" do
      expect(described_class.authorized?("someone", "correct-horse")).to be false
    end

    it "rejects nil credentials without raising" do
      expect(described_class.authorized?(nil, nil)).to be false
    end

    # Fail closed. Failing open on missing config is how /sidekiq ended up
    # publicly reachable in the first place.
    context "when the credentials are not configured" do
      it "rejects everything when both are blank" do
        stub_credentials(user: nil, password: nil)

        expect(described_class.authorized?("ops", "correct-horse")).to be false
        expect(described_class.authorized?(nil, nil)).to be false
        expect(described_class.authorized?("", "")).to be false
      end

      it "rejects when only the password is missing" do
        stub_credentials(user: "ops", password: "")

        expect(described_class.authorized?("ops", "")).to be false
      end
    end

    # Reading ENV per call, not at boot, is what makes a password rotation take
    # effect without a restart — and what makes these examples possible at all.
    it "reads the credentials on every call" do
      expect(described_class.authorized?("ops", "correct-horse")).to be true

      stub_credentials(user: "ops", password: "rotated")

      expect(described_class.authorized?("ops", "correct-horse")).to be false
      expect(described_class.authorized?("ops", "rotated")).to be true
    end
  end
end
