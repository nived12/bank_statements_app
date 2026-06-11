# frozen_string_literal: true

class FinancesController < ApplicationController
  before_action :authenticate!

  def index
    @savings = current_user.savings.kept.where(status: "active").includes(:goals, :categories).order(created_at: :desc)
    @debts = current_user.debts.kept.where(status: "active").order(created_at: :desc)
    @goals = current_user.goals.kept.where(status: "active").order(created_at: :desc)
  end
end
