class ErrorsController < ApplicationController
  skip_before_action :authenticate!
  skip_before_action :check_session_timeout
  skip_before_action :set_current_user
  after_action :reset_current_user, only: []

  def not_found
    if api_request?
      render_api_error("NOT_FOUND", "Endpoint not found", :not_found)
    else
      respond_to do |format|
        format.html { render "errors/not_found", status: :not_found, layout: false }
        format.json { render json: { error: "Not Found" }, status: :not_found }
      end
    end
  end

  def internal_server_error
    if api_request?
      render_api_error("INTERNAL_ERROR", "An internal error occurred", :internal_server_error)
    else
      respond_to do |format|
        format.html { render "errors/internal_server_error", status: :internal_server_error, layout: false }
        format.json { render json: { error: "Internal Server Error" }, status: :internal_server_error }
      end
    end
  end

  private

  def api_request?
    request.original_fullpath.start_with?("/api/")
  end

  def render_api_error(code, message, status)
    render json: {
      error: {
        message: message,
        code: code
      }
    }, status: status
  end
end
