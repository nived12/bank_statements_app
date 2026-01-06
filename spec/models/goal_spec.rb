require "rails_helper"

RSpec.describe Goal, type: :model do
  let(:user) { create(:user) }
  let(:savings_goal) do
    create(
      :goal,
      user: user,
      name: "Vacation Fund",
      goal_type: "savings_goal",
      start_date: 6.months.ago,
      deadline: 3.months.from_now
    )
  end
  let(:debt_goal) do
    create(
      :goal,
      user: user,
      name: "Pay Off Credit Card",
      goal_type: "debt_payoff",
      debt_strategy: "avalanche",
      start_date: 1.year.ago,
      deadline: 6.months.from_now
    )
  end

  describe "associations" do
    it "belongs to a user" do
      expect(savings_goal.user).to eq(user)
    end

    it "has many goal_savings" do
      expect(savings_goal.goal_savings).to be_empty
    end

    it "has many savings through goal_savings" do
      expect(savings_goal.savings).to be_empty
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
      expect(Goal.statuses).to eq(
        {
                "active" => "active",
                "completed" => "completed",
                "paused" => "paused",
                "archived" => "archived"
              }
      )
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

    it "requires deadline to be after start_date" do
      savings_goal.deadline = savings_goal.start_date - 1.day
      expect(savings_goal).not_to be_valid
      expect(savings_goal.errors[:deadline]).to include("debe ser posterior a la fecha de inicio")
    end

    it "requires debt_strategy for debt_payoff goals" do
      debt_goal.debt_strategy = nil
      expect(debt_goal).not_to be_valid
      expect(debt_goal.errors[:debt_strategy]).to include("debe seleccionarse para metas de pago de deudas")
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
      create(
        :goal,
        user: user,
        goal_type: "debt_payoff",
        debt_strategy: "snowball"
      )
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
      early_goal = create(:goal, user: user, start_date: Date.current, deadline: 1.month.from_now)
      late_goal = create(:goal, user: user, start_date: Date.current, deadline: 1.year.from_now)
      user_goals = Goal.where(id: [early_goal.id, late_goal.id]).by_deadline
      expect(user_goals.first).to eq(early_goal)
      expect(user_goals.last).to eq(late_goal)
    end

    it "filters savings goals" do
      expect(Goal.savings_goals).to include(savings_goal_2)
      expect(Goal.savings_goals).not_to include(debt_goal_2)
    end

    it "filters debt payoff goals" do
      expect(Goal.debt_payoff_goals).to include(debt_goal_2)
      expect(Goal.debt_payoff_goals).not_to include(savings_goal_2)
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
  end
end
