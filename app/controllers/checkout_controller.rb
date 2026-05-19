# frozen_string_literal: true

class CheckoutController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  def success
  end
end
