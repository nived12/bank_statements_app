# app/services/dashboard/preferences_service.rb
class Dashboard::PreferencesService < ApplicationService
  def initialize(user)
    @user = user
  end

  def call
    ensure_layout_exists
    load_preferences
  rescue => e
    Rails.logger.error "Error loading dashboard preferences: #{e.message}"
    default_preferences
  end

  private

  def ensure_layout_exists
    @user.ensure_dashboard_layout unless @user.dashboard_layout.present?
  end

  def load_preferences
    @user.dashboard_layout.widgets
  end

  def default_preferences
    DashboardLayout::DEFAULT_WIDGETS.dup
  end
end
