# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goals", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:category) { create(:category, user: user) }

  before do
    sign_in_user user
  end

  describe "GET /goals" do
    it "returns successful response" do
      get goals_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /goals/:id" do
    let(:goal) { create(:goal, user: user) }

    it "returns successful response" do
      get goal_path(goal)
      expect(response).to have_http_status(:success)
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }

      it "prevents access to other user's goals" do
        get goal_path(other_user_goal)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /goals/new" do
    it "returns successful response" do
      get new_goal_path
      expect(response).to have_http_status(:success)
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

      it "returns unprocessable entity status" do
        post goals_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(goal.debt_strategy).to eq("avalanche")
      end

      it "creates debt payoff goal with name" do
        expect {
          post goals_path, params: debt_params
        }.to change(Goal, :count).by(1)

        goal = Goal.last
        expect(goal.name).to eq("Credit Card Payoff")
      end
    end
  end

  describe "GET /goals/:id/edit" do
    let(:goal) { create(:goal, user: user) }

    it "returns successful response" do
      get edit_goal_path(goal)
      expect(response).to have_http_status(:success)
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
    let(:goal) { create(:goal, user: user, name: "Original Name") }

    context "with valid parameters" do
      let(:valid_params) do
        {
          goal: {
            name: "Updated Name",
            color: "#FF0000"
          }
        }
      end

      it "updates the goal" do
        patch goal_path(goal), params: valid_params
        goal.reload
        expect(goal.name).to eq("Updated Name")
        expect(goal.color).to eq("#FF0000")
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
            name: ""
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
        expect(response).to have_http_status(:unprocessable_content)
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

  describe "PATCH /goals/:id with status actions" do
    describe "complete action" do
      let(:goal) { create(:goal, user: user, status: "active") }

      it "marks goal as completed" do
        patch goal_path(goal), params: { status_action: "complete" }
        goal.reload
        expect(goal.status).to eq("completed")
      end

      it "redirects to goal show page" do
        patch goal_path(goal), params: { status_action: "complete" }
        expect(response).to redirect_to(goal_path(goal))
      end

      it "shows success message" do
        patch goal_path(goal), params: { status_action: "complete" }
        expect(flash[:notice]).to eq(I18n.t("goals.complete"))
      end

      context "with force completion" do
        let(:goal_to_force) { create(:goal, user: user, status: "active") }

        it "completes with status action" do
          patch goal_path(goal_to_force), params: { status_action: "complete" }
          goal_to_force.reload
          expect(goal_to_force.status).to eq("completed")
        end
      end
    end

    describe "pause action" do
      let(:goal) { create(:goal, user: user, status: "active") }

      it "pauses the goal" do
        patch goal_path(goal), params: { status_action: "pause" }
        goal.reload
        expect(goal.status).to eq("paused")
      end

      it "redirects to goal show page" do
        patch goal_path(goal), params: { status_action: "pause" }
        expect(response).to redirect_to(goal_path(goal))
      end
    end

    describe "resume action" do
      let(:goal) { create(:goal, user: user, status: "paused") }

      it "resumes the goal" do
        patch goal_path(goal), params: { status_action: "resume" }
        goal.reload
        expect(goal.status).to eq("active")
      end

      it "redirects to goal show page" do
        patch goal_path(goal), params: { status_action: "resume" }
        expect(response).to redirect_to(goal_path(goal))
      end
    end

    describe "archive action" do
      let(:goal) { create(:goal, user: user, status: "active") }

      it "archives the goal" do
        patch goal_path(goal), params: { status_action: "archive" }
        goal.reload
        expect(goal.status).to eq("archived")
      end

      it "redirects to goals index" do
        patch goal_path(goal), params: { status_action: "archive" }
        expect(response).to redirect_to(goals_path)
      end
    end
  end

  describe "service integration" do
    it "uses CreateService for goal creation" do
      params = {
        goal: {
          name: "Test Goal",
          goal_type: "savings_goal",
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
      expect(goal.name).to eq("Test Goal")
    end

    it "uses UpdateService for goal updates" do
      goal = create(:goal, user: user, name: "Old Name")

      patch goal_path(goal), params: { goal: { name: "New Name" } }

      goal.reload
      expect(goal.name).to eq("New Name")
    end

    it "uses UpdateService for status changes" do
      goal = create(:goal, user: user, status: "active")

      patch goal_path(goal), params: { status_action: "complete" }

      goal.reload
      expect(goal.status).to eq("completed")
    end
  end
end
