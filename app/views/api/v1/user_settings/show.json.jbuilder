json.data do
  json.notify_statement_imports  @settings.notify_statement_imports
  json.notify_goal_milestones    @settings.notify_goal_milestones
  json.notify_debt_reminders     @settings.notify_debt_reminders
  json.analytics_enabled         @settings.analytics_enabled
  json.analytics_notice_seen_at  @settings.analytics_notice_seen_at
end
