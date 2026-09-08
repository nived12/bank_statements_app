require "rails_helper"

# Calling the real Sentry.init would mutate global SDK state for the rest of the
# suite, so the block is captured and applied to a throwaway Configuration.
# Sentry::Configuration.new runs the same after(:initialize) hooks as production,
# which is what makes the "keeps the SDK's own defaults" example meaningful.
RSpec.describe "Sentry configuration" do
  let(:config) do
    captured = nil
    allow(Sentry).to receive(:init) { |&block| captured = Sentry::Configuration.new.tap(&block) }
    load Rails.root.join("config/initializers/sentry.rb").to_s
    captured
  end

  describe "excluded exceptions" do
    it "excludes the IP spoof error scanners trigger" do
      expect(config.exception_class_allowed?(ActionDispatch::RemoteIp::IpSpoofAttackError.new)).to be false
    end

    # The bug this guards produces no error anywhere: assigning instead of
    # appending drops the 15 defaults sentry-rails already set, and the same
    # scanners start reporting RoutingError instead.
    it "keeps the SDK's own defaults" do
      expect(config.exception_class_allowed?(ActiveRecord::RecordNotFound.new)).to be false
      expect(config.exception_class_allowed?(ActionController::RoutingError.new("nope"))).to be false
    end

    it "still reports ordinary errors" do
      expect(config.exception_class_allowed?(StandardError.new)).to be true
    end
  end

  describe "before_send" do
    let(:event) { double(request: nil) }

    def read_timeout(backtrace)
      RedisClient::ReadTimeoutError.new("timeout").tap { |e| e.set_backtrace(backtrace) }
    end

    it "drops Sidekiq fetch-loop read timeouts" do
      error = read_timeout(["/gems/sidekiq-8.0.10/lib/sidekiq/fetch.rb:45:in `retrieve_work'"])

      expect(config.before_send.call(event, exception: error)).to be_nil
    end

    it "keeps a Redis read timeout from anywhere else" do
      error = read_timeout(["/app/app/services/statements/importer.rb:12:in `call'"])

      expect(config.before_send.call(event, exception: error)).to eq(event)
    end
  end
end
