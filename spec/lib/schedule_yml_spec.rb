require "rails_helper"

# Guards config/schedule.yml. Every failure mode here is one that otherwise
# surfaces only as a line in the Railway boot log — or, worse, as a job that
# quietly never runs. That is exactly how Recurring::DailyDueJob went unnoticed
# from Phase 16 until 2026-07-31.
RSpec.describe "config/schedule.yml" do
  let(:schedule) do
    YAML.safe_load(ERB.new(File.read(Rails.root.join("config/schedule.yml"))).result, aliases: true)
  end

  let(:sidekiq_queues) do
    config = YAML.safe_load(
      ERB.new(File.read(Rails.root.join("config/sidekiq.yml"))).result,
      aliases: true, permitted_classes: [ Symbol ]
    )
    config[:queues].map(&:to_s)
  end

  it "is present and non-empty" do
    expect(schedule).to be_a(Hash)
    expect(schedule).not_to be_empty
  end

  # Deliberately no "load it into sidekiq-cron" test: that needs a live Redis in
  # CI and mutates shared cron state (it destroys the entries a developer's local
  # Sidekiq registered). The static checks below cover the same failure modes.

  it "has every required key" do
    schedule.each do |name, entry|
      expect(entry).to include("cron", "class", "queue"), "#{name} is missing a required key"
    end
  end

  it "names job classes that exist and are jobs" do
    schedule.each do |name, entry|
      klass = entry["class"].safe_constantize
      expect(klass).to be_present, "#{name}: #{entry["class"]} does not resolve"
      expect(klass.ancestors).to include(ActiveJob::Base), "#{name}: #{entry["class"]} is not an ActiveJob"
      expect(klass.instance_method(:perform).arity).to eq(0), "#{name}: #perform must take no arguments"
    end
  end

  it "uses cron expressions fugit can parse" do
    schedule.each do |name, entry|
      expect(Fugit.parse_cron(entry["cron"])).to be_present, "#{name}: #{entry["cron"].inspect} is unparseable"
    end
  end

  it "carries an explicit timezone" do
    # The app runs in UTC (config.time_zone), so a bare cron fires six hours off
    # for the primary market. Easy to get wrong and invisible until someone
    # notices mail arriving at 03:00.
    schedule.each do |name, entry|
      expect(entry["cron"].split.length).to be >= 6, "#{name}: #{entry["cron"].inspect} has no timezone suffix"
    end
  end

  it "only targets queues Sidekiq actually processes" do
    # CleanupExpiredTokensJob declared :low_priority while sidekiq.yml never
    # listed it, so the job would have been enqueued and never run.
    schedule.each do |name, entry|
      expect(sidekiq_queues).to include(entry["queue"]),
        "#{name}: queue #{entry["queue"].inspect} is not in config/sidekiq.yml (#{sidekiq_queues.inspect})"
    end
  end

  it "matches each job's own queue_as declaration" do
    schedule.each do |name, entry|
      declared = entry["class"].constantize.queue_name
      expect(declared).to eq(entry["queue"]),
        "#{name}: schedule says #{entry["queue"].inspect} but the class declares #{declared.inspect}"
    end
  end
end
