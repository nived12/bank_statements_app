# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recurring::DailyDueJob do
  let(:user) { create(:user) }
  let!(:bank_account) { create(:bank_account, user: user) }

  it "notifies for each active due series and skips non-due / non-active" do
    due_series      = create(:recurring_series, user: user, next_due_date: Date.current)
    future_series   = create(
      :recurring_series, user: user, next_due_date: Date.current + 5,
      description_signature: "future"
    )
    paused_series   = create(
      :recurring_series, :paused, user: user, next_due_date: Date.current,
      description_signature: "paused"
    )

    expect(Notifications::PushJob).to receive(:perform_later).once
    described_class.new.perform

    expect(due_series.reload.last_notified_on).to eq(Date.current)
    expect(future_series.reload.last_notified_on).to be_nil
    expect(paused_series.reload.last_notified_on).to be_nil
  end

  it "is idempotent — second run on same day does not re-notify" do
    create(:recurring_series, user: user, next_due_date: Date.current)
    expect(Notifications::PushJob).to receive(:perform_later).once
    2.times { described_class.new.perform }
  end
end
