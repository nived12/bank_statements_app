class LandingController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!

  def index
    @waitlist = Waitlist.new
  end
end
