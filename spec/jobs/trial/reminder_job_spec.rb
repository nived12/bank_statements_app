require "rails_helper"

RSpec.describe Trial::ReminderJob, type: :job do
  # trial_ends_at is set by a SubscriptionAccess after_create hook, so it has to
  # be overwritten after the record exists.
  def user_with_trial_ending_in(days, **attrs)
    create(:user, **attrs).tap do |u|
      u.update_columns(trial_ends_at: days.days.from_now)
    end
  end

  def enqueued_trial_emails
    ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:args].first == "ReminderMailer" && job[:args].second == "trial_ending"
    end
  end

  describe "milestone mapping" do
    # The ascending MILESTONES order is easy to invert, which would silently
    # send everyone the 7-day email, so map every day in the window explicitly.
    {
      7 => 7, 6 => 7, 5 => 7, 4 => 7,
      3 => 3, 2 => 3,
      1 => 1, 0 => 1
    }.each do |days_left, expected_stage|
      it "stamps stage #{expected_stage} for a trial #{days_left} day(s) out" do
        user = user_with_trial_ending_in(days_left)

        described_class.perform_now

        expect(user.reload.trial_reminder_stage).to eq(expected_stage)
      end
    end

    it "passes the actual days remaining to the mailer, not the milestone" do
      user = user_with_trial_ending_in(5)
      allow(ReminderMailer).to receive(:trial_ending).and_call_original

      described_class.perform_now

      expect(ReminderMailer).to have_received(:trial_ending).with(user, 5)
    end
  end

  describe "exclusions" do
    it "skips a user who opted out of trial reminders" do
      user = user_with_trial_ending_in(7)
      user.user_setting.update!(notify_trial_reminders: false)

      described_class.perform_now

      expect(enqueued_trial_emails).to be_empty
      # Stage stays nil so opting back in still delivers the milestones ahead.
      expect(user.reload.trial_reminder_stage).to be_nil
    end

    it "still emails a user who left reminders on" do
      user_with_trial_ending_in(7)

      described_class.perform_now

      expect(enqueued_trial_emails.size).to eq(1)
    end

    it "still emails a user with no settings row at all" do
      # Never configured is not the same as opted out. Getting this backwards would
      # silently cut off the only conversion path iOS has.
      user = user_with_trial_ending_in(7)
      user.user_setting.destroy
      user.reload

      described_class.perform_now

      expect(enqueued_trial_emails.size).to eq(1)
    end

    it "ignores a trial ending outside the 7-day window" do
      user = user_with_trial_ending_in(20)

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to be_nil
      expect(enqueued_trial_emails).to be_empty
    end

    it "still emails a trial that expired earlier the same day" do
      # The job runs mid-morning; a trial ending at 03:00 is already past but
      # the user is on their final day and should still hear from us.
      user = create(:user).tap { |u| u.update_columns(trial_ends_at: Time.current.beginning_of_day + 3.hours) }

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to eq(1)
    end

    it "includes a trial on the far edge of the window regardless of run time" do
      # Guards the upper bound: with a bare MILESTONES.max.days.from_now this
      # depended on the hour the job ran.
      travel_to(Time.current.change(hour: 23, min: 30)) do
        user = create(:user).tap { |u| u.update_columns(trial_ends_at: 7.days.from_now.change(hour: 2)) }

        described_class.perform_now

        expect(user.reload.trial_reminder_stage).to eq(7)
      end
    end

    it "ignores a trial one day beyond the window" do
      travel_to(Time.current.change(hour: 23, min: 30)) do
        user = create(:user).tap { |u| u.update_columns(trial_ends_at: 8.days.from_now.change(hour: 2)) }

        described_class.perform_now

        expect(user.reload.trial_reminder_stage).to be_nil
      end
    end

    it "ignores an already-expired trial" do
      user = user_with_trial_ending_in(-3)

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to be_nil
      expect(enqueued_trial_emails).to be_empty
    end

    it "ignores an unconfirmed user" do
      user = user_with_trial_ending_in(5, confirmed_at: nil)

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to be_nil
    end

    it "ignores a discarded user" do
      user = user_with_trial_ending_in(5)
      user.discard

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to be_nil
    end

    it "ignores a user with an active paid subscription" do
      user = user_with_trial_ending_in(5)
      allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(true)

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to be_nil
      expect(enqueued_trial_emails).to be_empty
    end
  end

  describe "idempotency" do
    it "does not resend on a second run the same day" do
      user_with_trial_ending_in(5)

      described_class.perform_now
      described_class.perform_now

      expect(enqueued_trial_emails.size).to eq(1)
    end

    it "sends each milestone exactly once across the trial" do
      user = user_with_trial_ending_in(7)

      described_class.perform_now
      expect(user.reload.trial_reminder_stage).to eq(7)

      user.update_columns(trial_ends_at: 3.days.from_now)
      described_class.perform_now
      expect(user.reload.trial_reminder_stage).to eq(3)

      user.update_columns(trial_ends_at: 1.day.from_now)
      described_class.perform_now
      expect(user.reload.trial_reminder_stage).to eq(1)

      described_class.perform_now

      expect(enqueued_trial_emails.size).to eq(3)
    end

    it "never sends a later-stage email after an earlier one" do
      user = user_with_trial_ending_in(1)
      described_class.perform_now
      expect(user.reload.trial_reminder_stage).to eq(1)

      # Should be impossible in practice, but the guard must hold regardless.
      user.update_columns(trial_ends_at: 6.days.from_now)
      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to eq(1)
      expect(enqueued_trial_emails.size).to eq(1)
    end

    it "does not backfill a skipped milestone" do
      # First seen with 2 days left: gets the 3-day email, never the 7-day one.
      user = user_with_trial_ending_in(2)

      described_class.perform_now

      expect(user.reload.trial_reminder_stage).to eq(3)
      expect(enqueued_trial_emails.size).to eq(1)
    end
  end

  describe "resilience" do
    it "continues past a user that raises" do
      boom = user_with_trial_ending_in(5)
      ok   = user_with_trial_ending_in(5)

      allow(ReminderMailer).to receive(:trial_ending).and_wrap_original do |original, user, days|
        raise "boom" if user.id == boom.id

        original.call(user, days)
      end

      expect { described_class.perform_now }.not_to raise_error

      expect(boom.reload.trial_reminder_stage).to be_nil
      expect(ok.reload.trial_reminder_stage).to eq(7)
    end
  end
end
