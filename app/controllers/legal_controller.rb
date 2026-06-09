# frozen_string_literal: true

class LegalController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  def privacy; end

  def terms; end

  def financial_data; end
end
