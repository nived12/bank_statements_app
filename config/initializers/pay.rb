# frozen_string_literal: true

Rails.configuration.to_prepare do
  Pay.setup do |config|
    config.enabled_processors = [:stripe]
    config.automount_routes = true
    config.routes_path = "/pay"
    config.default_product_name = "default"
    config.default_plan_name = "default"
  end
end
