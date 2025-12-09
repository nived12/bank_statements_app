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
      servers: [
        {
          url: "https://vitt.io",
          description: "Production server"
        },
        {
          url: "http://localhost:3000",
          description: "Development server"
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT",
            description: "JWT access token obtained from /api/v1/login or /api/v1/signup"
          }
        },
        schemas: {
          Error: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  message: { type: :string, description: "Human-readable error message" },
                  code: { type: :string, description: "Machine-readable error code" },
                  field: { type: :string, description: "Field name for validation errors (optional)" }
                },
                required: [:message]
              }
            },
            required: [:error]
          },
          ValidationError: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  message: { type: :string, description: "Human-readable error message" },
                  code: { type: :string, description: "Machine-readable error code" },
                  details: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        field: { type: :string },
                        message: { type: :string },
                        code: { type: :string }
                      }
                    },
                    description: "Field-specific validation errors"
                  }
                },
                required: [:message, :code]
              }
            },
            required: [:error]
          },
          User: {
            type: :object,
            properties: {
              id: { type: :integer, description: "User ID" },
              email: { type: :string, format: :email, description: "User email address" },
              first_name: { type: :string, description: "User's first name" },
              last_name: { type: :string, description: "User's last name" },
              full_name: { type: :string, description: "User's full name (first + last)" },
              confirmed: { type: :boolean, description: "Whether user's email is confirmed" },
              avatar_url: { type: :string, format: :uri, description: "User's avatar URL" }
            },
            required: [:id, :email, :first_name, :last_name, :full_name, :avatar_url]
          },
          AuthenticationResponse: {
            type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  access_token: { type: :string, description: "JWT access token (expires in 15 minutes)" },
                  refresh_token: { type: :string, description: "JWT refresh token (expires in 7 days)" },
                  expires_in: { type: :integer, description: "Access token expiration time in seconds" },
                  token_type: { type: :string, description: "Token type (Bearer)" },
                  user: { "$ref" => "#/components/schemas/User" }
                },
                required: [:access_token, :refresh_token, :user]
              }
            },
            required: [:data]
          },
          RefreshResponse: {
            type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  access_token: { type: :string, description: "New JWT access token (expires in 15 minutes)" },
                  refresh_token: { type: :string, description: "New JWT refresh token (expires in 7 days)" },
                  expires_in: { type: :integer, description: "Access token expiration time in seconds" },
                  token_type: { type: :string, description: "Token type (Bearer)" }
                },
                required: [:access_token, :refresh_token]
              }
            },
            required: [:data]
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
