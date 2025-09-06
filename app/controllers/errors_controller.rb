class ErrorsController < ApplicationController
  skip_before_action :authenticate!
  skip_before_action :check_session_timeout
  skip_before_action :set_current_user
  after_action :reset_current_user, only: []

  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: false }
      format.json { render json: { error: "Not Found" }, status: :not_found }
    end
  end

  def internal_server_error
    respond_to do |format|
      format.html { render "errors/internal_server_error", status: :internal_server_error, layout: false }
      format.json { render json: { error: "Internal Server Error" }, status: :internal_server_error }
    end
  end
end
