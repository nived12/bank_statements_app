module LocaleConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    I18n.locale = locale_from_params || I18n.default_locale
  end

  def locale_from_params
    return unless params[:locale] && I18n.available_locales.map(&:to_s).include?(params[:locale])

    params[:locale]
  end
end
