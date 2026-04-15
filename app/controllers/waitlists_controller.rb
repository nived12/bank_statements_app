class WaitlistsController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!

  def create
    @waitlist = Waitlist.new(waitlist_params)
    @waitlist.locale = I18n.locale.to_s

    if Waitlist.exists?(email: @waitlist.email)
      @waitlist_success = true
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to landing_root_path, notice: t("landing.waitlist.already_registered") }
      end
    elsif @waitlist.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landing_root_path, notice: t("landing.waitlist.success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "waitlist-form",
            partial: "landing/waitlist_form",
            locals: { waitlist: @waitlist }
          )
        end
        format.html { render "landing/index", status: :unprocessable_entity }
      end
    end
  end

  private

  def waitlist_params
    params.require(:waitlist).permit(:email)
  end
end
