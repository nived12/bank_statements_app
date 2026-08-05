# frozen_string_literal: true

# One-click opt-out for lifecycle email. Reached only from a signed token in the
# email itself, so it works logged out and must not require consent re-acceptance —
# MarketingLayout already skips both gates and gives the public layout.
#
# GET renders a confirmation page; POST performs the opt-out. Mail clients that
# honour RFC 8058 (Gmail, Apple Mail) POST here directly from their own native
# "Unsubscribe" button, which is why forgery protection is skipped.
class UnsubscribesController < ApplicationController
  include MarketingLayout

  skip_forgery_protection

  before_action :set_user

  def show
  end

  def create
    # A settings row is created with every user, but an opt-out must not 500 on the
    # one account where that never happened — this is the last place to be fragile.
    settings = @user.user_setting || @user.create_user_setting!
    settings.update!(notify_trial_reminders: false)
  end

  private

  def set_user
    @user = User.kept.find_by_token_for(:email_unsubscribe, params[:token])
    return if @user

    # No redirect to sign-in: someone clicking unsubscribe is the last person
    # who wants a login form.
    render :invalid, status: :not_found
  end
end
