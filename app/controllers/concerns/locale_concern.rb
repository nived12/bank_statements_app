module LocaleConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    I18n.locale = locale_from_params || locale_from_header || I18n.default_locale
  end

  def locale_from_params
    return unless params[:locale] && I18n.available_locales.map(&:to_s).include?(params[:locale])

    params[:locale]
  end

  def locale_from_header
    locale = request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first
    return unless locale && I18n.available_locales.map(&:to_s).include?(locale)

    locale
  end

  # This is being used in the views to generate the URL for the language switcher
  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end
end
