# frozen_string_literal: true

class CheckoutController < ApplicationController
  include SubscriptionManagement

  layout "landing"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  # Stripe returns the mobile in-app browser here after payment. Unauthenticated:
  # the in-app browser carries no session cookie, so the sync is keyed off the
  # checkout session id rather than current_user.
  def success
    sync_subscription_from_stripe_session(params[:stripe_checkout_session_id])
  end
end
