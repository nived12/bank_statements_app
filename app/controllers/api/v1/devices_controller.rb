# frozen_string_literal: true

module Api
  module V1
    class DevicesController < BaseController
      before_action :set_device, only: [:destroy]

      # POST /api/v1/devices
      def create
        @device = current_user.devices.find_or_initialize_by(push_token: device_params[:push_token])
        @device.assign_attributes(device_params.merge(active: true))

        if @device.save
          render :create, status: :ok
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to register device",
            status: :unprocessable_content,
            details: format_validation_errors(@device.errors)
          )
        end
      end

      # DELETE /api/v1/devices/:push_token
      def destroy
        @device.destroy!
        head :no_content
      end

      private

      def set_device
        @device = current_user.devices.find_by!(push_token: params[:push_token])
      rescue ActiveRecord::RecordNotFound
        render_error("NOT_FOUND", message: "Device not found", status: :not_found)
      end

      def device_params
        params.require(:device).permit(:push_token, :platform)
      end
    end
  end
end
