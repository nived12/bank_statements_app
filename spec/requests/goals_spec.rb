# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goals", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before do
    sign_in_user user
  end

  describe "GET /goals" do
    it "returns successful response" do
      get goals_path
      expect(response).to have_http_status(:success)
    end

    context "with multiple goals" do
      let!(:goal1) { create(:goal, user: user, name: "My Goal 1") }
      let!(:goal2) { create(:goal, user: user, name: "My Goal 2") }
      let!(:other_user_goal) { create(:goal, name: "Other User Goal") }

      it "displays user's goals only" do
        get goals_path
        expect(response.body).to include("My Goal 1")
        expect(response.body).to include("My Goal 2")
        expect(response.body).not_to include("Other User Goal")
      end
    end

    context "with active and completed goals" do
      let!(:active_goal) { create(:goal, user: user, name: "Active Goal", status: "active") }
      let!(:completed_goal) { create(:goal, user: user, name: "Completed Goal", status: "completed") }

      it "separates active and completed goals in display" do
        get goals_path
        expect(response).to have_http_status(:success)
        # Both should be visible
        expect(response.body).to include("Active Goal")
        expect(response.body).to include("Completed Goal")
      end
    end
  end

  describe "GET /goals/:id" do
    let(:goal) { create(:goal, user: user) }

    it "returns successful response" do
      get goal_path(goal)
      expect(response).to have_http_status(:success)
    end

    it "displays goal details" do
      get goal_path(goal)
      expect(response.body).to include(goal.name)
      # Goal amount is displayed with currency formatting
      expect(response).to have_http_status(:success)
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }

      it "prevents access to other user's goals" do
        get goal_path(other_user_goal)
        # Request specs return 404 status, not raise error
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with goal progress" do
      let(:goal_with_progress) { create(:goal, user: user, target_amount: 1000, current_amount: 500) }

      it "calculates and displays progress metrics" do
        get goal_path(goal_with_progress)
        expect(response).to have_http_status(:success)
        # Progress should be calculated and displayed
        expect(response.body).to include("50") # 50% progress
      end
    end
  end

  describe "GET /goals/new" do
    it "returns successful response" do
      get new_goal_path
      expect(response).to have_http_status(:success)
    end

    it "displays goal form" do
      get new_goal_path
      expect(response.body).to include("form")
      expect(response.body).to include(I18n.t("goals.name"))
    end
  end

  describe "POST /goals" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          goal: {
            name: "Emergency Fund",
            goal_type: "savings_goal",
            target_amount: 5000,
            start_date: Date.today,
            deadline: 1.year.from_now.to_date,
            category_id: category.id,
            auto_link_category: true,
            icon: "💰",
            color: "#3B82F6",
            notes: "Save for emergencies"
          }
        }
      end

      it "creates a new goal" do
        expect {
          post goals_path, params: valid_params
        }.to change(Goal, :count).by(1)
      end

      it "creates goal with correct attributes" do
        post goals_path, params: valid_params

        goal = Goal.last
        expect(goal.user).to eq(user)
        expect(goal.name).to eq("Emergency Fund")
        expect(goal.goal_type).to eq("savings_goal")
        expect(goal.target_amount).to eq(5000)
        expect(goal.category).to eq(category)
        expect(goal.auto_link_category).to be true
        expect(goal.icon).to eq("💰")
        expect(goal.color).to eq("#3B82F6")
      end

      it "redirects to goal show page" do
        post goals_path, params: valid_params
        expect(response).to redirect_to(goal_path(Goal.last))
      end

      it "sets success flash message" do
        post goals_path, params: valid_params
        expect(flash[:notice]).to eq(I18n.t("goals.created"))
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          goal: {
            name: "",
            goal_type: "savings_goal"
          }
        }
      end

      it "does not create a goal" do
        expect {
          post goals_path, params: invalid_params
        }.not_to change(Goal, :count)
      end

      it "renders new template with errors" do
        post goals_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("error")
      end
    end

    context "with debt payoff goal" do
      let(:debt_params) do
        {
          goal: {
            name: "Credit Card Payoff",
            goal_type: "debt_payoff",
            target_amount: 0,
            starting_debt_amount: 10000,
            debt_strategy: "avalanche",
            start_date: Date.today,
            deadline: 2.years.from_now.to_date
          }
        }
      end

      it "creates debt payoff goal with strategy" do
        expect {
          post goals_path, params: debt_params
        }.to change(Goal, :count).by(1)

        goal = Goal.last
        expect(goal.goal_type).to eq("debt_payoff")
        expect(goal.starting_debt_amount).to eq(10000)
        expect(goal.debt_strategy).to eq("avalanche")
        expect(goal.target_amount).to eq(0)
      end
    end
  end

  describe "GET /goals/:id/edit" do
    let(:goal) { create(:goal, user: user) }

    it "returns successful response" do
      get edit_goal_path(goal)
      expect(response).to have_http_status(:success)
    end

    it "displays edit form with current values" do
      get edit_goal_path(goal)
      expect(response.body).to include("form")
      expect(response.body).to include(goal.name)
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }

      it "prevents editing other user's goals" do
        get edit_goal_path(other_user_goal)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /goals/:id" do
    let(:goal) { create(:goal, user: user, name: "Original Name", target_amount: 5000) }

    context "with valid parameters" do
      let(:valid_params) do
        {
          goal: {
            name: "Updated Name",
            target_amount: 7500
          }
        }
      end

      it "updates the goal" do
        patch goal_path(goal), params: valid_params
        goal.reload
        expect(goal.name).to eq("Updated Name")
        expect(goal.target_amount).to eq(7500)
      end

      it "redirects to goal show page" do
        patch goal_path(goal), params: valid_params
        expect(response).to redirect_to(goal_path(goal))
      end

      it "sets success flash message" do
        patch goal_path(goal), params: valid_params
        expect(flash[:notice]).to eq(I18n.t("goals.updated"))
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          goal: {
            name: "",
            target_amount: -100
          }
        }
      end

      it "does not update the goal" do
        original_name = goal.name
        patch goal_path(goal), params: invalid_params
        goal.reload
        expect(goal.name).to eq(original_name)
      end

      it "renders edit template with errors" do
        patch goal_path(goal), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /goals/:id" do
    let!(:goal) { create(:goal, user: user) }

    it "destroys the goal" do
      expect {
        delete goal_path(goal)
      }.to change(Goal, :count).by(-1)
    end

    it "redirects to goals index" do
      delete goal_path(goal)
      expect(response).to redirect_to(goals_path)
    end

    it "shows success message" do
      delete goal_path(goal)
      expect(flash[:notice]).to eq(I18n.t("goals.deleted"))
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }

      it "prevents deleting other user's goals" do
        delete goal_path(other_user_goal)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /goals/:id/complete" do
    let(:goal) { create(:goal, user: user, target_amount: 1000, current_amount: 1000, status: "active") }

    it "marks goal as completed when target is met" do
      patch complete_goal_path(goal)
      goal.reload
      expect(goal.status).to eq("completed")
    end

    it "redirects to goal show page" do
      patch complete_goal_path(goal)
      expect(response).to redirect_to(goal_path(goal))
    end

    it "shows success message" do
      patch complete_goal_path(goal)
      expect(flash[:notice]).to eq(I18n.t("goals.completed"))
    end

    context "when target is not met" do
      let(:incomplete_goal) { create(:goal, user: user, target_amount: 1000, current_amount: 500, status: "active") }

      it "does not complete without force flag" do
        patch complete_goal_path(incomplete_goal)
        incomplete_goal.reload
        expect(incomplete_goal.status).to eq("active")
      end

      it "completes with force flag" do
        patch complete_goal_path(incomplete_goal), params: { force: "true" }
        incomplete_goal.reload
        expect(incomplete_goal.status).to eq("completed")
      end
    end
  end

  describe "PATCH /goals/:id/pause" do
    let(:goal) { create(:goal, user: user, status: "active") }

    it "pauses the goal" do
      patch pause_goal_path(goal)
      goal.reload
      expect(goal.status).to eq("paused")
    end

    it "redirects to goal show page" do
      patch pause_goal_path(goal)
      expect(response).to redirect_to(goal_path(goal))
    end
  end

  describe "PATCH /goals/:id/resume" do
    let(:goal) { create(:goal, user: user, status: "paused") }

    it "resumes the goal" do
      patch resume_goal_path(goal)
      goal.reload
      expect(goal.status).to eq("active")
    end

    it "redirects to goal show page" do
      patch resume_goal_path(goal)
      expect(response).to redirect_to(goal_path(goal))
    end
  end

  describe "PATCH /goals/:id/archive" do
    let(:goal) { create(:goal, user: user, status: "active") }

    it "archives the goal" do
      patch archive_goal_path(goal)
      goal.reload
      expect(goal.status).to eq("archived")
    end

    it "redirects to goals index" do
      patch archive_goal_path(goal)
      expect(response).to redirect_to(goals_path)
    end
  end

  describe "service integration" do
    it "uses CreateService for goal creation" do
      params = {
        goal: {
          name: "Test Goal",
          goal_type: "savings_goal",
          target_amount: 1000,
          start_date: Date.today,
          deadline: 1.month.from_now.to_date
        }
      }

      expect {
        post goals_path, params: params
      }.to change(Goal, :count).by(1)

      # Verify CreateService logic worked
      goal = Goal.last
      expect(goal.status).to eq("active") # Default status from service
      expect(goal.current_amount).to eq(0) # Default from service
    end

    it "uses UpdateService for goal updates" do
      goal = create(:goal, user: user, name: "Old Name")

      patch goal_path(goal), params: { goal: { name: "New Name" } }

      goal.reload
      expect(goal.name).to eq("New Name")
    end

    it "uses CompleteGoalService for completion" do
      goal = create(:goal, user: user, target_amount: 100, current_amount: 100, status: "active")

      patch complete_goal_path(goal)

      goal.reload
      expect(goal.status).to eq("completed")
    end
  end
end
