# frozen_string_literal: true

Rails.application.config.belvo = ActiveSupport::OrderedOptions.new
Rails.application.config.belvo.secret_id = ENV.fetch("BELVO_SECRET_ID", nil)
Rails.application.config.belvo.secret_password = ENV.fetch("BELVO_SECRET_PASSWORD", nil)
Rails.application.config.belvo.environment = ENV.fetch("BELVO_ENV", "sandbox")
