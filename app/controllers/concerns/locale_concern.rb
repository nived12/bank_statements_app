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
    locale = params[:locale]
    return nil unless locale
    return nil unless I18n.available_locales.map(&:to_s).include?(locale)
    locale
  end

  def locale_from_header
    locale = request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first
    return nil unless locale
    return nil unless I18n.available_locales.map(&:to_s).include?(locale)
    locale
  end

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end
end
