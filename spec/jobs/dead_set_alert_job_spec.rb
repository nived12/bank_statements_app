require "rails_helper"
require "sidekiq/api"

RSpec.describe DeadSetAlertJob do
  # A plain Array satisfies everything the job asks of a DeadSet: #size, #first
  # and Enumerable. Stubbing avoids needing Redis in CI.
  def stub_dead_set(entries)
    allow(Sidekiq::DeadSet).to receive(:new).and_return(entries)
  end

  def entry(display_class, at)
    instance_double(Sidekiq::SortedEntry, display_class: display_class, at: at)
  end

  before do
    allow(Sentry).to receive(:capture_message)
    allow(Rails.logger).to receive(:error)
  end

  describe "#perform" do
    it "reports a non-empty dead set to Sentry" do
      stub_dead_set([entry("ReminderMailer#trial_ending", 3.days.ago)])

      described_class.new.perform

      expect(Sentry).to have_received(:capture_message)
        .with(/dead set/, hash_including(level: :error))
    end

    it "says nothing when the dead set is empty" do
      stub_dead_set([])

      described_class.new.perform

      expect(Sentry).not_to have_received(:capture_message)
      expect(Rails.logger).not_to have_received(:error)
    end

    # display_class unwraps the ActiveJob wrapper. Without it the April 2026
    # incident would have read as 14 identical MailDeliveryJobs.
    it "breaks the report down by unwrapped job class" do
      entries = [
        entry("ReminderMailer#trial_ending", 2.days.ago),
        entry("ReminderMailer#trial_ending", 1.day.ago),
        entry("StatementIngestJob", 1.hour.ago)
      ]
      stub_dead_set(entries)

      described_class.new.perform

      expect(Sentry).to have_received(:capture_message) do |_message, options|
        expect(options[:extra][:by_class]).to eq(
          "ReminderMailer#trial_ending" => 2, "StatementIngestJob" => 1
        )
      end
    end

    it "reports the oldest entry and the true total" do
      stub_dead_set([entry("A", 5.days.ago), entry("B", 1.day.ago)])

      described_class.new.perform

      expect(Sentry).to have_received(:capture_message) do |_message, options|
        expect(options[:extra][:total]).to eq(2)
        expect(options[:extra][:oldest_at]).to eq(5.days.ago.iso8601)
      end
    end

    # Sentry groups capture_message by message text, so a count in the string
    # would open a new issue every time the number moved.
    it "keeps the message text constant as the count changes" do
      messages = []
      allow(Sentry).to receive(:capture_message) { |message, _options| messages << message }

      stub_dead_set([entry("A", 1.day.ago)])
      described_class.new.perform

      stub_dead_set(Array.new(5) { entry("A", 1.day.ago) })
      described_class.new.perform

      expect(messages.uniq.size).to eq(1)
    end

    # "Only alert on new deaths" is the logic that produced the four-month blind
    # spot: the first alert gets missed and it never fires again.
    it "reports the same backlog again on the next run" do
      stub_dead_set([entry("A", 1.day.ago)])

      2.times { described_class.new.perform }

      expect(Sentry).to have_received(:capture_message).twice
    end

    it "caps how much of the dead set it scans" do
      stub_dead_set(Array.new(described_class::SCAN_LIMIT + 10) { entry("A", 1.day.ago) })

      described_class.new.perform

      expect(Sentry).to have_received(:capture_message) do |_message, options|
        expect(options[:extra][:total]).to eq(described_class::SCAN_LIMIT + 10)
        expect(options[:extra][:scanned]).to eq(described_class::SCAN_LIMIT)
      end
    end
  end

  it "runs on a queue Sidekiq actually processes" do
    expect(described_class.new.queue_name).to eq("low_priority")
  end

  # schedule_yml_spec validates whatever is in the file but never asserts that
  # this job is in it. Without this, deleting the entry leaves the suite green.
  it "is scheduled" do
    schedule = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/schedule.yml"))).result, aliases: true)

    expect(schedule.values.map { |entry| entry["class"] }).to include(described_class.name)
  end
end
