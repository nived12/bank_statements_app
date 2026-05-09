# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::PushJob, type: :job do
  let(:user) { create(:user) }

  before do
    allow(Notifications::PushSender).to receive(:call).and_return(double(success?: true))
  end

  describe "#perform" do
    context "without notification_type" do
      it "always calls PushSender" do
        described_class.perform_now(user_id: user.id, title: "T", body: "B")
        expect(Notifications::PushSender).to have_received(:call).once
      end
    end

    context "with notification_type" do
      it "calls PushSender when preference is enabled (default)" do
        described_class.perform_now(
          user_id: user.id, title: "T", body: "B",
          notification_type: "statement_imports"
        )
        expect(Notifications::PushSender).to have_received(:call).once
      end

      it "skips PushSender when statement_imports preference is disabled" do
        user.user_setting.update!(preferences: { "notify_statement_imports" => false })
        described_class.perform_now(
          user_id: user.id, title: "T", body: "B",
          notification_type: "statement_imports"
        )
        expect(Notifications::PushSender).not_to have_received(:call)
      end

      it "skips PushSender when goal_milestones preference is disabled" do
        user.user_setting.update!(preferences: { "notify_goal_milestones" => false })
        described_class.perform_now(
          user_id: user.id, title: "T", body: "B",
          notification_type: "goal_milestones"
        )
        expect(Notifications::PushSender).not_to have_received(:call)
      end

      it "skips PushSender when debt_reminders preference is disabled" do
        user.user_setting.update!(preferences: { "notify_debt_reminders" => false })
        described_class.perform_now(
          user_id: user.id, title: "T", body: "B",
          notification_type: "debt_reminders"
        )
        expect(Notifications::PushSender).not_to have_received(:call)
      end

      it "does not skip when a different pref is disabled" do
        user.user_setting.update!(preferences: { "notify_goal_milestones" => false })
        described_class.perform_now(
          user_id: user.id, title: "T", body: "B",
          notification_type: "statement_imports"
        )
        expect(Notifications::PushSender).to have_received(:call).once
      end
    end

    context "with unknown user_id" do
      it "returns early without raising" do
        expect { described_class.perform_now(user_id: 0, title: "T", body: "B") }.not_to raise_error
        expect(Notifications::PushSender).not_to have_received(:call)
      end
    end
  end
end
