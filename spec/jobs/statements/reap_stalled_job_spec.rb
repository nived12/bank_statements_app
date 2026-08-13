require "rails_helper"

RSpec.describe Statements::ReapStalledJob do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }

  def statement(status:, updated_at:)
    file = create(:statement_file, user: user, bank_account: bank_account, status: status)
    file.update_column(:updated_at, updated_at)
    file
  end

  describe "#perform" do
    it "fails out a statement stuck in processing past the threshold" do
      stuck = statement(status: :processing, updated_at: 2.hours.ago)

      described_class.new.perform

      stuck.reload
      expect(stuck.status).to eq("error")
      expect(stuck.error_message).to include("processing_interrupted:")
      expect(stuck.user_facing_error).to eq(I18n.t("statement_files.processing_interrupted"))
      expect(stuck.processed_at).to be_present
    end

    it "leaves a processing statement alone while it is still within the threshold" do
      fresh = statement(status: :processing, updated_at: (described_class::STALE_AFTER - 5.minutes).ago)

      described_class.new.perform

      expect(fresh.reload.status).to eq("processing")
    end

    it "does not touch statements in other statuses, however old" do
      old_completed = statement(status: :completed, updated_at: 3.days.ago)
      old_pending = statement(status: :pending, updated_at: 3.days.ago)

      described_class.new.perform

      expect(old_completed.reload.status).to eq("completed")
      expect(old_pending.reload.status).to eq("pending")
    end

    it "does not overwrite an existing error message" do
      already_failed = statement(status: :error, updated_at: 3.days.ago)
      already_failed.update!(error_message: "password_required: PDF is password protected")

      described_class.new.perform

      expect(already_failed.reload.error_message).to include("password_required")
    end

    it "does not clobber a statement that finished between the scan and the write" do
      stuck = statement(status: :processing, updated_at: 2.hours.ago)

      # Simulate the job completing inside the window: the row changes after the
      # staleness scan has already selected it, but before the reap writes.
      allow_any_instance_of(StatementFile).to receive(:with_lock).and_wrap_original do |original, &block|
        StatementFile.where(id: stuck.id).update_all(
          status: StatementFile.statuses[:completed], updated_at: Time.current
        )
        original.call(&block)
      end

      described_class.new.perform

      expect(stuck.reload.status).to eq("completed")
    end

    it "keeps reaping after one row fails to save" do
      first = statement(status: :processing, updated_at: 2.hours.ago)
      second = statement(status: :processing, updated_at: 90.minutes.ago)

      allow_any_instance_of(StatementFile).to receive(:update!).and_wrap_original do |original, *args|
        raise ActiveRecord::StatementInvalid, "connection blip" if original.receiver.id == first.id

        original.call(*args)
      end

      described_class.new.perform

      expect(first.reload.status).to eq("processing")
      expect(second.reload.status).to eq("error")
    end

    it "reaps every stalled statement, not just the first" do
      first = statement(status: :processing, updated_at: 2.hours.ago)
      second = statement(status: :processing, updated_at: 90.minutes.ago)

      described_class.new.perform

      expect([ first.reload.status, second.reload.status ]).to eq([ "error", "error" ])
    end
  end

  it "runs on a queue Sidekiq actually processes" do
    expect(described_class.new.queue_name).to eq("low_priority")
  end
end
