# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::UpdateService do
  let(:user) { create(:user) }
  let(:goal) { create(:goal, user: user) }

  describe "#call" do
    context "with regular goal updates" do
      it "updates goal successfully" do
        result = described_class.call(goal, { name: "Updated Name" })

        expect(result).to be_success
        expect(goal.reload.name).to eq("Updated Name")
      end

      it "auto-completes goal when target is reached" do
        goal.update!(current_amount: 4900, target_amount: 5000)

        result = described_class.call(goal, { current_amount: 5000 })

        expect(result).to be_success
        expect(goal.reload.status).to eq("completed")
      end

      it "fails when deadline is before start_date" do
        result = described_class.call(goal, { deadline: goal.start_date - 1.day })

        expect(result).to be_failure
      end
    end

    context "with status actions" do
      describe "pause action" do
        it "pauses the goal successfully" do
          goal.update!(status: "active")

          result = described_class.call(goal, { status_action: "pause" })

          expect(result).to be_success
          expect(goal.reload.status).to eq("paused")
        end
      end

      describe "resume action" do
        it "resumes the goal successfully" do
          goal.update!(status: "paused")

          result = described_class.call(goal, { status_action: "resume" })

          expect(result).to be_success
          expect(goal.reload.status).to eq("active")
        end
      end

      describe "archive action" do
        it "archives the goal successfully" do
          goal.update!(status: "active")

          result = described_class.call(goal, { status_action: "archive" })

          expect(result).to be_success
          expect(goal.reload.status).to eq("archived")
        end
      end

      describe "complete action" do
        context "when target is met" do
          it "completes the goal successfully" do
            goal.update!(target_amount: 1000, current_amount: 1000, status: "active")

            result = described_class.call(goal, { status_action: "complete" })

            expect(result).to be_success
            expect(goal.reload.status).to eq("completed")
          end
        end

        context "when target is not met" do
          it "fails to complete the goal" do
            goal.update!(target_amount: 1000, current_amount: 500, status: "active")

            result = described_class.call(goal, { status_action: "complete" })

            expect(result).to be_failure
            expect(result.errors[:goal]).to be_present
          end

          it "completes when forced" do
            goal.update!(target_amount: 1000, current_amount: 500, status: "active")

            result = described_class.call(goal, { status_action: "complete", force: "true" })

            expect(result).to be_success
            expect(goal.reload.status).to eq("completed")
          end
        end

        context "with debt payoff goals" do
          it "completes when debt is paid down to target" do
            goal.update!(
              goal_type: "debt_payoff",
              starting_debt_amount: 10000,
              target_amount: 2000,
              current_amount: 8000,
              debt_strategy: "snowball",
              status: "active"
            )

            result = described_class.call(goal, { status_action: "complete" })

            expect(result).to be_success
            expect(goal.reload.status).to eq("completed")
          end

          it "fails when debt is not paid down enough" do
            goal.update!(
              goal_type: "debt_payoff",
              starting_debt_amount: 10000,
              target_amount: 2000,
              current_amount: 5000,
              debt_strategy: "snowball",
              status: "active"
            )

            result = described_class.call(goal, { status_action: "complete" })

            expect(result).to be_failure
            expect(result.errors[:goal]).to be_present
          end
        end
      end

      describe "invalid status action" do
        it "fails with invalid status action" do
          result = described_class.call(goal, { status_action: "invalid" })

          expect(result).to be_failure
          expect(result.errors[:status_action]).to include("is not valid")
        end
      end
    end
  end
end
