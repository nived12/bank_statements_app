# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join("swagger").to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'

  # Common server configuration
  common_servers = [
    {
      url: "https://vitt.io",
      description: "Production server"
    },
    {
      url: "http://localhost:3000",
      description: "Development server"
    }
  ]

  # Common security schemes
  common_security_schemes = {
    Bearer: {
      type: :http,
      scheme: :bearer,
      bearerFormat: "JWT",
      description: "JWT access token obtained from /api/v1/login or /api/v1/signup"
    }
  }

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "VITTIO API V1",
        version: "v1",
        description: "API documentation for VITTIO - Personal Finance Management Platform",
        contact: {
          name: "VITTIO Support",
          url: "https://vitt.io"
        }
      },
      paths: {},
      servers: common_servers,
      components: {
        securitySchemes: common_security_schemes
      }
    }
  }

  ##
  # Load Parameters & Responses Definitions
  #
  Rails.root.glob("spec/integration/support/**/*.json").each do |file|
    # File Basename
    basename = file.basename.to_s.split(".").first

    # File relative path
    # => "parameters/.../file_name.json" | "response_body/.../file_name.json"
    relative_path = file.relative_path_from("#{File.expand_path(".")}/spec/integration/support").to_s

    # levels from the relative path
    # => [ "response_body", "v1", "file_name"]
    relative_path_levels = relative_path.split("/")

    # exclude the file_name
    relative_path_levels.pop

    # Assigns suffix based on the type of file uploaded
    schema_suffix =
      case relative_path_levels.reverse!.pop
      when "response_body"
        "_response"
      when "parameters"
        "_params"
      else
        ""
      end

    # reorders the levels and merge the prefix based on the path
    schema_prefix = relative_path_levels.reverse!.any? ? "#{relative_path_levels.join("_")}_" : ""

    # Determine which version file(s) to load the schema into
    # Files in v1/ or v2/ directories go to their respective version
    # Files in root (response_body/ or parameters/) without version go to v1
    api_versions =
      if relative_path.include?("/v2/")
        ["v2/swagger.yaml"]
      elsif relative_path.include?("/v1/")
        ["v1/swagger.yaml"]
      else
        # Root level files (no version) go to v1
        ["v1/swagger.yaml"]
      end

    parsed_schema = JSON.parse(file.read)
    api_versions.each do |api_version|
      config.openapi_specs.deep_merge!(
        {
          api_version => {
            components: {
              schemas: { "#{schema_prefix}#{basename}#{schema_suffix}" => parsed_schema }
            }
          }
        }
      )
    end
  end

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml

  # Route specs to correct OpenAPI document based on file path
  config.define_derived_metadata(file_path: %r{spec/integration/api/v1}) do |metadata|
    metadata[:openapi_spec] = "v1/swagger.yaml" unless metadata.key?(:openapi_spec)
  end
end
