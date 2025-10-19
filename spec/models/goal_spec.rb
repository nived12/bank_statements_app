require "rails_helper"

RSpec.describe Goal, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:savings_goal) do
    create(:goal,
           user: user,
           name: "Vacation Fund",
           goal_type: "savings_goal",
           target_amount: 5000,
           current_amount: 2000,
           start_date: 6.months.ago,
           deadline: 3.months.from_now)
  end
  let(:debt_goal) do
    create(:goal,
           user: user,
           name: "Pay Off Credit Card",
           goal_type: "debt_payoff",
           target_amount: 0,
           starting_debt_amount: 10000,
           current_amount: 6000,
           debt_strategy: "avalanche",
           start_date: 1.year.ago,
           deadline: 6.months.from_now)
  end

  describe "associations" do
    it "belongs to a user" do
      expect(savings_goal.user).to eq(user)
    end

    it "belongs to a category (optional)" do
      goal_with_category = create(:goal, user: user, category: category)
      expect(goal_with_category.category).to eq(category)
    end

    it "has many goal_transactions" do
      expect(savings_goal.goal_transactions).to be_empty
    end

    it "has many transactions through goal_transactions" do
      expect(savings_goal.transactions).to be_empty
    end
  end

  describe "enums" do
    it "has goal_type enum" do
      expect(Goal.goal_types).to eq({ "savings_goal" => "savings_goal", "debt_payoff" => "debt_payoff" })
    end

    it "has debt_strategy enum" do
      expect(Goal.debt_strategies).to eq({ "snowball" => "snowball", "avalanche" => "avalanche" })
    end

    it "has status enum" do
      expect(Goal.statuses).to eq({
        "active" => "active",
        "completed" => "completed",
        "paused" => "paused",
        "archived" => "archived"
      })
    end
  end

  describe "validations" do
    it "is valid with all required attributes" do
      expect(savings_goal).to be_valid
    end

    it "requires a name" do
      savings_goal.name = nil
      expect(savings_goal).not_to be_valid
      expect(savings_goal.errors[:name]).to be_present
    end

    it "requires name to be at least 3 characters" do
      savings_goal.name = "ab"
      expect(savings_goal).not_to be_valid
    end

    it "requires name to be at most 100 characters" do
      savings_goal.name = "a" * 101
      expect(savings_goal).not_to be_valid
    end

    it "requires a goal_type" do
      savings_goal.goal_type = nil
      expect(savings_goal).not_to be_valid
    end

    it "requires a target_amount" do
      savings_goal.target_amount = nil
      expect(savings_goal).not_to be_valid
    end

    it "allows target_amount to be 0 for debt payoff goals" do
      debt_payoff_goal = build(:goal, :debt_payoff, user: user, target_amount: 0)
      expect(debt_payoff_goal).to be_valid
    end

    it "requires target_amount to be non-negative" do
      savings_goal.target_amount = -100
      expect(savings_goal).not_to be_valid
    end

    it "requires current_amount to be greater than or equal to 0" do
      savings_goal.current_amount = -100
      expect(savings_goal).not_to be_valid
    end

    it "requires a start_date" do
      savings_goal.start_date = nil
      expect(savings_goal).not_to be_valid
    end

    it "requires a deadline" do
      savings_goal.deadline = nil
      expect(savings_goal).not_to be_valid
    end

    it "requires deadline to be after start_date" do
      savings_goal.deadline = savings_goal.start_date - 1.day
      expect(savings_goal).not_to be_valid
      expect(savings_goal.errors[:deadline]).to include("must be after start date")
    end

    it "requires debt_strategy for debt_payoff goals" do
      debt_goal.debt_strategy = nil
      expect(debt_goal).not_to be_valid
      expect(debt_goal.errors[:debt_strategy]).to include("must be selected for debt payoff goals")
    end

    it "requires starting_debt_amount for debt_payoff goals" do
      debt_goal.starting_debt_amount = nil
      expect(debt_goal).not_to be_valid
      expect(debt_goal.errors[:starting_debt_amount]).to include("must be provided for debt payoff goals")
    end

    it "does not require debt_strategy for savings goals" do
      expect(savings_goal).to be_valid
      expect(savings_goal.debt_strategy).to be_nil
    end
  end

  describe "scopes" do
    let!(:active_goal) { create(:goal, user: user, status: "active") }
    let!(:completed_goal) { create(:goal, user: user, status: "completed") }
    let!(:paused_goal) { create(:goal, user: user, status: "paused") }
    let!(:archived_goal) { create(:goal, user: user, status: "archived") }
    let!(:savings_goal_2) { create(:goal, user: user, goal_type: "savings_goal") }
    let!(:debt_goal_2) do
      create(:goal,
             user: user,
             goal_type: "debt_payoff",
             debt_strategy: "snowball",
             starting_debt_amount: 5000)
    end

    it "filters active goals" do
      expect(Goal.active).to include(active_goal)
      expect(Goal.active).not_to include(completed_goal)
    end

    it "filters completed goals" do
      expect(Goal.completed).to include(completed_goal)
      expect(Goal.completed).not_to include(active_goal)
    end

    it "filters paused goals" do
      expect(Goal.paused).to include(paused_goal)
      expect(Goal.paused).not_to include(active_goal)
    end

    it "filters archived goals" do
      expect(Goal.archived).to include(archived_goal)
      expect(Goal.archived).not_to include(active_goal)
    end

    it "orders by deadline" do
      early_goal = create(:goal, user: user, deadline: 1.month.from_now)
      late_goal = create(:goal, user: user, deadline: 6.months.from_now)
      expect(Goal.by_deadline.first).to eq(early_goal)
      expect(Goal.by_deadline.last).to eq(late_goal)
    end

    it "filters savings goals" do
      expect(Goal.savings_goals).to include(savings_goal_2)
      expect(Goal.savings_goals).not_to include(debt_goal_2)
    end

    it "filters debt payoff goals" do
      expect(Goal.debt_payoff_goals).to include(debt_goal_2)
      expect(Goal.debt_payoff_goals).not_to include(savings_goal_2)
    end

    it "filters goals with auto_link enabled" do
      auto_link_goal = create(:goal, user: user, auto_link_category: true)
      expect(Goal.with_auto_link).to include(auto_link_goal)
      expect(Goal.with_auto_link).not_to include(savings_goal_2)
    end
  end

  describe "#progress_percentage" do
    it "calculates percentage for savings goal" do
      # 2000 / 5000 = 40%
      expect(savings_goal.progress_percentage).to eq(40.0)
    end

    it "calculates percentage for debt payoff goal" do
      # Total to pay: 10000 - 0 = 10000
      # Paid: 6000
      # Progress: 6000 / 10000 = 60%
      expect(debt_goal.progress_percentage).to eq(60.0)
    end

    it "returns 0 when current_amount is 0" do
      savings_goal.current_amount = 0
      expect(savings_goal.progress_percentage).to eq(0.0)
    end

    it "returns 0 when target_amount is 0 for savings" do
      savings_goal.target_amount = 0
      expect(savings_goal.progress_percentage).to eq(0.0)
    end
  end

  describe "#amount_remaining" do
    it "calculates remaining amount for savings goal" do
      # 5000 - 2000 = 3000
      expect(savings_goal.amount_remaining).to eq(3000)
    end

    it "calculates remaining debt for debt payoff goal" do
      # Starting: 10000, Target: 0, Current paid: 6000
      # Remaining: 10000 - 6000 - 0 = 4000
      expect(debt_goal.amount_remaining).to eq(4000)
    end
  end

  describe "#days_remaining" do
    it "calculates days until deadline" do
      goal = create(:goal, user: user, deadline: 30.days.from_now)
      expect(goal.days_remaining).to be_within(1).of(30)
    end

    it "returns negative for past deadlines" do
      goal = create(:goal, user: user, deadline: 10.days.ago)
      expect(goal.days_remaining).to be < 0
    end
  end

  describe "#months_remaining" do
    it "calculates months until deadline" do
      goal = create(:goal, user: user, deadline: 3.months.from_now)
      expect(goal.months_remaining).to be_within(1).of(3)
    end

    it "returns 0 for past deadlines" do
      goal = create(:goal, user: user, deadline: 1.month.ago)
      expect(goal.months_remaining).to eq(0)
    end
  end

  describe "#monthly_contribution_needed" do
    it "calculates monthly amount needed for savings goal" do
      # Assuming 3 months remaining, need 3000 more
      # 3000 / 3 = 1000 per month
      expect(savings_goal.monthly_contribution_needed).to be > 0
    end

    it "returns 0 when goal is completed" do
      savings_goal.update(status: "completed")
      expect(savings_goal.monthly_contribution_needed).to eq(0)
    end

    it "returns 0 when months_remaining is 0" do
      savings_goal.update(deadline: Date.today)
      expect(savings_goal.monthly_contribution_needed).to eq(0)
    end

    it "returns 0 when amount_remaining is 0 or negative" do
      savings_goal.update(current_amount: 5000)
      expect(savings_goal.monthly_contribution_needed).to eq(0)
    end
  end

  describe "#on_track?" do
    it "returns true when progress exceeds time elapsed" do
      # Create a goal that's 50% through time and 60% complete
      goal = create(:goal,
                    user: user,
                    target_amount: 1000,
                    current_amount: 600,
                    start_date: 100.days.ago,
                    deadline: 100.days.from_now)
      expect(goal.on_track?).to be true
    end

    it "returns false when behind schedule" do
      # Create a goal that's 50% through time but only 20% complete
      goal = create(:goal,
                    user: user,
                    target_amount: 1000,
                    current_amount: 200,
                    start_date: 100.days.ago,
                    deadline: 100.days.from_now)
      expect(goal.on_track?).to be false
    end

    it "returns true when completed" do
      savings_goal.update(status: "completed")
      expect(savings_goal.on_track?).to be true
    end
  end

  describe "#behind_schedule?" do
    it "returns true when not on track and not completed" do
      goal = create(:goal,
                    user: user,
                    target_amount: 1000,
                    current_amount: 100,
                    start_date: 100.days.ago,
                    deadline: 100.days.from_now)
      expect(goal.behind_schedule?).to be true
    end

    it "returns false when completed" do
      savings_goal.update(status: "completed")
      expect(savings_goal.behind_schedule?).to be false
    end

    it "returns false when past deadline" do
      past_date = Date.today - 1
      goal = create(:goal, user: user, deadline: past_date, start_date: 2.weeks.ago.to_date)
      expect(goal.behind_schedule?).to be false
    end
  end

  describe "#past_deadline?" do
    it "returns true when deadline has passed and not completed" do
      past_date = Date.today - 1
      goal = create(:goal, user: user, deadline: past_date, start_date: 2.weeks.ago.to_date)
      expect(goal.past_deadline?).to be true
    end

    it "returns false when completed even if past deadline" do
      past_date = Date.today - 1
      goal = create(:goal, user: user, deadline: past_date, start_date: 2.weeks.ago.to_date, status: "completed")
      expect(goal.past_deadline?).to be false
    end

    it "returns false when deadline is in the future" do
      expect(savings_goal.past_deadline?).to be false
    end
  end

  describe "#approaching_deadline?" do
    it "returns true when deadline is within 30 days" do
      goal = create(:goal, user: user, deadline: 15.days.from_now)
      expect(goal.approaching_deadline?).to be true
    end

    it "returns false when deadline is more than 30 days away" do
      goal = create(:goal, user: user, deadline: 45.days.from_now)
      expect(goal.approaching_deadline?).to be false
    end

    it "returns false when completed" do
      goal = create(:goal, user: user, deadline: 15.days.from_now, status: "completed")
      expect(goal.approaching_deadline?).to be false
    end
  end

  describe "#complete_goal!" do
    it "marks goal as completed" do
      savings_goal.complete_goal!
      expect(savings_goal.status).to eq("completed")
    end

    it "sets current_amount to target_amount" do
      savings_goal.complete_goal!
      expect(savings_goal.current_amount).to eq(savings_goal.target_amount)
    end
  end

  describe "#pause!" do
    it "marks goal as paused" do
      savings_goal.pause!
      expect(savings_goal.status).to eq("paused")
    end
  end

  describe "#resume!" do
    it "marks goal as active" do
      savings_goal.update(status: "paused")
      savings_goal.resume!
      expect(savings_goal.status).to eq("active")
    end
  end

  describe "#archive!" do
    it "marks goal as archived" do
      savings_goal.archive!
      expect(savings_goal.status).to eq("archived")
    end
  end

  describe "#recalculate_current_amount!" do
    let(:bank_account) { create(:bank_account, user: user) }
    let(:transaction1) do
      create(:transaction, user: user, bank_account: bank_account, amount: 500)
    end
    let(:transaction2) do
      create(:transaction, user: user, bank_account: bank_account, amount: 300)
    end

    before do
      create(:goal_transaction, goal: savings_goal, txn: transaction1, amount_applied: 500)
      create(:goal_transaction, goal: savings_goal, txn: transaction2, amount_applied: 300)
    end

    it "recalculates current_amount from goal_transactions" do
      savings_goal.recalculate_current_amount!
      expect(savings_goal.current_amount).to eq(800)
    end
  end

  describe "default values" do
    it "sets default color" do
      goal = Goal.new
      expect(goal.color).to eq("#3B82F6")
    end

    it "sets default status to active" do
      goal = Goal.new
      expect(goal.status).to eq("active")
    end

    it "sets default current_amount to 0" do
      goal = Goal.new
      expect(goal.current_amount).to eq(0)
    end

    it "sets default auto_link_category to false" do
      goal = Goal.new
      expect(goal.auto_link_category).to eq(false)
    end
  end

  describe "destruction behavior" do
    let!(:bank_account) { create(:bank_account, user: user) }
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account) }
    let!(:goal_transaction) do
      create(:goal_transaction, goal: savings_goal, txn: transaction, amount_applied: 100)
    end

    it "destroys associated goal_transactions" do
      expect { savings_goal.destroy }.to change { GoalTransaction.count }.by(-1)
    end

    it "does not destroy associated transactions" do
      expect { savings_goal.destroy }.not_to change { Transaction.count }
    end
  end
end
