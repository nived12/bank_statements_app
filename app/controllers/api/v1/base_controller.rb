# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::BaseController
    # Base controller for all API v1 endpoints
    #
    # Key features:
    # - JSON-only responses
    # - JWT authentication
    # - CSRF protection disabled (using JWT instead)
    # - Custom error handling
    # - Rate limiting headers
    #
    class BaseController < ActionController::API
      include ApiAuthenticatable
      include ApiErrorHandler
      include Pagy::Backend

      # Override current_user to use JWT authentication
      # (ApiAuthenticatable sets this via before_action)
      attr_reader :current_user

      before_action :require_legal_consent!

      protected

      ##
      # Paginate records with consistent API pagination behavior
      # Handles both ActiveRecord relations and Arrays
      #
      # @param unpaginated_records [ActiveRecord::Relation, Array] Records to paginate
      # @return [ActiveRecord::Relation, Array] Paginated records
      #
      # @example
      #   @transactions = paginate(current_user.transactions)
      #   # Sets @pagy instance variable for use in Jbuilder templates
      #
      def paginate(unpaginated_records)
        if unpaginated_records.is_a?(Array)
          @pagy, records = pagy_array(unpaginated_records, limit: page_size, page: page)
        else
          @pagy, records = pagy(unpaginated_records, limit: page_size, page: page)
        end
        records
      rescue Pagy::OverflowError
        # If page is beyond total pages, reset to page 1
        if unpaginated_records.is_a?(Array)
          @pagy, records = pagy_array(unpaginated_records, limit: page_size, page: 1)
        else
          @pagy, records = pagy(unpaginated_records, limit: page_size, page: 1)
        end
        records
      end

      ##
      # Get page size from params, default to 20
      # Clients can customize via ?page_size=50
      #
      # @return [Integer] Number of items per page
      #
      def page_size
        size = params[:page_size]&.to_i || 20
        # Cap at 100 to prevent abuse
        [size, 100].min
      end

      ##
      # Get page number from params
      # Supports both ?page=2 and ?page_token=2 for flexibility
      #
      # @return [Integer] Page number
      #
      def page
        (params[:page_token] || params[:page] || 1).to_i
      end

      ##
      # Format ActiveModel validation errors for API response
      # Converts errors hash into array of field-level error objects
      #
      # @param errors [ActiveModel::Errors] The validation errors object
      # @return [Array<Hash>] Array of formatted error objects
      #
      # @example
      #   format_validation_errors(user.errors)
      #   # => [
      #   #   { field: "email", message: "Email can't be blank", code: "BLANK" },
      #   #   { field: "password", message: "Password is too short", code: "TOO_SHORT" }
      #   # ]
      #
      ##
      # Require the current API user to have a confirmed email address.
      # Renders 403 EMAIL_NOT_CONFIRMED if not confirmed.
      # OAuth users are always confirmed.
      #
      def require_legal_consent!
        # Skip for unauthenticated requests (auth guard handles those separately)
        return if current_user.nil?
        # Skip for unconfirmed users (email confirmation guard handles them first)
        return unless current_user.confirmed?
        return if current_user.legal_consent_current?

        render_error(
          "TERMS_NOT_ACCEPTED",
          message: I18n.t("api.legal.terms_not_accepted"),
          status: :forbidden
        )
      end

      def require_confirmed_user!
        return if current_user.confirmed?

        render_error(
          "EMAIL_NOT_CONFIRMED",
          message: "Please confirm your email address before making changes.",
          status: :forbidden
        )
      end

      def format_validation_errors(errors)
        errors.details.flat_map do |field, details_array|
          details_array.map.with_index do |detail, index|
            {
              field: field.to_s,
              message: errors.full_messages_for(field)[index] || errors.full_messages_for(field).first,
              code: detail[:error].to_s.upcase
            }
          end
        end
      end
    end
  end
end
