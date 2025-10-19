# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalsController, type: :controller do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before do
    sign_in_user user
  end

  describe "GET #index" do
    it "returns a successful response" do
      get :index
      expect(response).to be_successful
    end

    it "assigns user's goals" do
      goal1 = create(:goal, user: user)
      goal2 = create(:goal, user: user)
      other_user_goal = create(:goal)

      get :index

      expect(assigns(:goals)).to include(goal1, goal2)
      expect(assigns(:goals)).not_to include(other_user_goal)
    end

    it "separates active and completed goals" do
      active_goal = create(:goal, user: user, status: "active")
      completed_goal = create(:goal, user: user, status: "completed")

      get :index

      expect(assigns(:active_goals)).to include(active_goal)
      expect(assigns(:active_goals)).not_to include(completed_goal)
      expect(assigns(:completed_goals)).to include(completed_goal)
      expect(assigns(:completed_goals)).not_to include(active_goal)
    end
  end

  describe "GET #show" do
    let(:goal) { create(:goal, user: user) }

    it "returns a successful response" do
      get :show, params: { id: goal.id }
      expect(response).to be_successful
    end

    it "assigns the requested goal" do
      get :show, params: { id: goal.id }
      expect(assigns(:goal)).to eq(goal)
    end

    it "calculates progress metrics" do
      get :show, params: { id: goal.id }
      expect(assigns(:progress)).to be_present
    end

    it "does not allow access to other user's goal" do
      other_user_goal = create(:goal)
      expect {
        get :show, params: { id: other_user_goal.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET #new" do
    it "returns a successful response" do
      get :new
      expect(response).to be_successful
    end

    it "assigns a new goal" do
      get :new
      expect(assigns(:goal)).to be_a_new(Goal)
    end
  end

  describe "POST #create" do
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
          post :create, params: valid_params
        }.to change(Goal, :count).by(1)
      end

      it "redirects to the goal show page" do
        post :create, params: valid_params
        expect(response).to redirect_to(goal_path(Goal.last))
      end

      it "shows a success message" do
        post :create, params: valid_params
        expect(flash[:notice]).to eq(I18n.t("goals.created"))
      end

      it "creates goal with correct attributes" do
        post :create, params: valid_params

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
          post :create, params: invalid_params
        }.not_to change(Goal, :count)
      end

      it "renders the new template" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
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

      it "creates a debt payoff goal" do
        expect {
          post :create, params: debt_params
        }.to change(Goal, :count).by(1)

        goal = Goal.last
        expect(goal.goal_type).to eq("debt_payoff")
        expect(goal.starting_debt_amount).to eq(10000)
        expect(goal.debt_strategy).to eq("avalanche")
      end
    end
  end

  describe "GET #edit" do
    let(:goal) { create(:goal, user: user) }

    it "returns a successful response" do
      get :edit, params: { id: goal.id }
      expect(response).to be_successful
    end

    it "assigns the requested goal" do
      get :edit, params: { id: goal.id }
      expect(assigns(:goal)).to eq(goal)
    end
  end

  describe "PATCH #update" do
    let(:goal) { create(:goal, user: user, name: "Original Name") }

    context "with valid parameters" do
      let(:valid_params) do
        {
          id: goal.id,
          goal: {
            name: "Updated Name",
            target_amount: 7500
          }
        }
      end

      it "updates the goal" do
        patch :update, params: valid_params
        goal.reload
        expect(goal.name).to eq("Updated Name")
        expect(goal.target_amount).to eq(7500)
      end

      it "redirects to the goal show page" do
        patch :update, params: valid_params
        expect(response).to redirect_to(goal_path(goal))
      end

      it "shows a success message" do
        patch :update, params: valid_params
        expect(flash[:notice]).to eq(I18n.t("goals.updated"))
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          id: goal.id,
          goal: {
            name: "",
            target_amount: -100
          }
        }
      end

      it "does not update the goal" do
        original_name = goal.name
        patch :update, params: invalid_params
        goal.reload
        expect(goal.name).to eq(original_name)
      end

      it "renders the edit template" do
        patch :update, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:goal) { create(:goal, user: user) }

    it "destroys the goal" do
      expect {
        delete :destroy, params: { id: goal.id }
      }.to change(Goal, :count).by(-1)
    end

    it "redirects to goals index" do
      delete :destroy, params: { id: goal.id }
      expect(response).to redirect_to(goals_path)
    end

    it "shows a success message" do
      delete :destroy, params: { id: goal.id }
      expect(flash[:notice]).to eq(I18n.t("goals.deleted"))
    end
  end

  describe "PATCH #complete" do
    let(:goal) { create(:goal, user: user, target_amount: 1000, current_amount: 1000, status: "active") }

    it "completes the goal when target is met" do
      patch :complete, params: { id: goal.id }
      goal.reload
      expect(goal.status).to eq("completed")
    end

    it "redirects to goal show page" do
      patch :complete, params: { id: goal.id }
      expect(response).to redirect_to(goal_path(goal))
    end

    it "shows a success message" do
      patch :complete, params: { id: goal.id }
      expect(flash[:notice]).to eq(I18n.t("goals.completed"))
    end

    context "when target is not met" do
      let(:incomplete_goal) { create(:goal, user: user, target_amount: 1000, current_amount: 500, status: "active") }

      it "does not complete the goal without force flag" do
        patch :complete, params: { id: incomplete_goal.id }
        incomplete_goal.reload
        expect(incomplete_goal.status).to eq("active")
      end

      it "completes the goal with force flag" do
        patch :complete, params: { id: incomplete_goal.id, force: "true" }
        incomplete_goal.reload
        expect(incomplete_goal.status).to eq("completed")
      end
    end
  end

  describe "PATCH #pause" do
    let(:goal) { create(:goal, user: user, status: "active") }

    it "pauses the goal" do
      patch :pause, params: { id: goal.id }
      goal.reload
      expect(goal.status).to eq("paused")
    end

    it "redirects to goal show page" do
      patch :pause, params: { id: goal.id }
      expect(response).to redirect_to(goal_path(goal))
    end

    it "shows a success message" do
      patch :pause, params: { id: goal.id }
      expect(flash[:notice]).to eq(I18n.t("goals.paused"))
    end
  end

  describe "PATCH #resume" do
    let(:goal) { create(:goal, user: user, status: "paused") }

    it "resumes the goal" do
      patch :resume, params: { id: goal.id }
      goal.reload
      expect(goal.status).to eq("active")
    end

    it "redirects to goal show page" do
      patch :resume, params: { id: goal.id }
      expect(response).to redirect_to(goal_path(goal))
    end

    it "shows a success message" do
      patch :resume, params: { id: goal.id }
      expect(flash[:notice]).to eq(I18n.t("goals.resumed"))
    end
  end

  describe "PATCH #archive" do
    let(:goal) { create(:goal, user: user, status: "active") }

    it "archives the goal" do
      patch :archive, params: { id: goal.id }
      goal.reload
      expect(goal.status).to eq("archived")
    end

    it "redirects to goals index" do
      patch :archive, params: { id: goal.id }
      expect(response).to redirect_to(goals_path)
    end

    it "shows a success message" do
      patch :archive, params: { id: goal.id }
      expect(flash[:notice]).to eq(I18n.t("goals.archived"))
    end
  end
end
