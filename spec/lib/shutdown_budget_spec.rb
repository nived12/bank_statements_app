require "rails_helper"

# Sidekiq re-queues in-flight jobs at the END of its shutdown timeout. If Railway
# SIGKILLs the container before that, the jobs are lost with no error and no
# retry — a statement file then sits in `processing` forever. The two numbers
# live in different files and nothing else connects them.
RSpec.describe "shutdown budget" do
  let(:railway) { JSON.parse(File.read(Rails.root.join("railway.json"))) }

  let(:sidekiq_config) do
    YAML.safe_load(
      ERB.new(File.read(Rails.root.join("config/sidekiq.yml"))).result,
      aliases: true, permitted_classes: [ Symbol ]
    )
  end

  it "gives Sidekiq a shutdown timeout" do
    expect(sidekiq_config[:timeout]).to be_a(Integer)
  end

  it "declares a draining window rather than relying on Railway's default" do
    expect(railway.dig("deploy", "drainingSeconds")).to be_a(Integer)
  end

  it "drains for longer than Sidekiq takes to shut down" do
    draining = railway.dig("deploy", "drainingSeconds")

    expect(draining).to be > sidekiq_config[:timeout],
      "drainingSeconds (#{draining}) must exceed Sidekiq's :timeout " \
      "(#{sidekiq_config[:timeout]}) or in-flight jobs are killed before they re-queue"
  end

  it "starts the app through the signal-forwarding boot script" do
    # A bare `sh -c '... & ...'` start command cannot forward SIGTERM to a
    # backgrounded Sidekiq, which is what makes the budget above meaningful.
    expect(railway.dig("deploy", "startCommand")).to eq("./bin/boot")
    expect(File).to be_executable(Rails.root.join("bin/boot"))
  end
end
