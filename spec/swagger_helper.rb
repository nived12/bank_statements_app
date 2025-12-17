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
          },
          Transaction: {
            type: :object,
            properties: {
              id: { type: :integer, description: "Transaction ID" },
              date: { type: :string, format: :date, description: "Transaction date (ISO 8601)" },
              description: { type: :string, description: "Transaction description" },
              amount: { type: :number, description: "Transaction amount (negative for expenses)" },
              transaction_type: { type: :string, enum: ["income", "fixed_expense", "variable_expense", "transfer_in", "transfer_out"], description: "Type of transaction" },
              source: { type: :string, enum: ["manual", "statement_file"], description: "Source of transaction" },
              merchant: { type: :string, nullable: true, description: "Merchant name" },
              reference: { type: :string, nullable: true, description: "Reference number" },
              bank_account: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  account_type: { type: :string }
                }
              },
              category: {
                type: :object,
                nullable: true,
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  icon: { type: :string, nullable: true }
                }
              },
              is_transfer: { type: :boolean, description: "Whether this is a transfer transaction" },
              transfer_account: {
                type: :object,
                nullable: true,
                properties: {
                  id: { type: :integer },
                  name: { type: :string }
                }
              },
              created_at: { type: :string, format: "date-time", description: "Creation timestamp (ISO 8601)" },
              updated_at: { type: :string, format: "date-time", description: "Last update timestamp (ISO 8601)" }
            },
            required: [:id, :date, :description, :amount, :transaction_type, :source, :bank_account, :is_transfer, :created_at, :updated_at]
          },
          Pagination: {
            type: :object,
            properties: {
              current_page: { type: :integer, description: "Current page number" },
              next_page: { type: :integer, nullable: true, description: "Next page number (null if on last page)" },
              prev_page: { type: :integer, nullable: true, description: "Previous page number (null if on first page)" },
              total_pages: { type: :integer, description: "Total number of pages" },
              total_items: { type: :integer, description: "Total number of items across all pages" },
              page_size: { type: :integer, description: "Number of items per page" },
              from: { type: :integer, description: "Record number of first item on this page" },
              to: { type: :integer, description: "Record number of last item on this page" }
            },
            required: [:current_page, :total_pages, :total_items, :page_size, :from, :to]
          },
          TransactionStats: {
            type: :object,
            properties: {
              total_transactions: { type: :integer, description: "Total number of transactions" },
              income_total: { type: :number, description: "Total income amount" },
              expenses_total: { type: :number, description: "Total expenses amount (negative)" },
              equity_total: { type: :number, description: "Net amount (income + expenses)" },
              income_count: { type: :integer, description: "Number of income transactions" },
              fixed_expense_count: { type: :integer, description: "Number of fixed expense transactions" },
              variable_expense_count: { type: :integer, description: "Number of variable expense transactions" },
              category_count: { type: :integer, description: "Number of unique categories used" }
            },
            required: [:total_transactions, :income_total, :expenses_total, :equity_total, :income_count, :fixed_expense_count, :variable_expense_count, :category_count]
          },
          TransactionsListResponse: {
            type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  transactions: {
                    type: :array,
                    items: { "$ref" => "#/components/schemas/Transaction" }
                  }
                },
                required: [:transactions]
              },
              meta: {
                type: :object,
                properties: {
                  pagination: { "$ref" => "#/components/schemas/Pagination" },
                  stats: { "$ref" => "#/components/schemas/TransactionStats" },
                  filters: {
                    type: :object,
                    properties: {
                      bank_account_id: { type: :integer, nullable: true },
                      statement_file_id: { type: :integer, nullable: true },
                      transaction_type: { type: :string, nullable: true },
                      from_date: { type: :string, nullable: true },
                      to_date: { type: :string, nullable: true },
                      search: { type: :string, nullable: true },
                      sort: { type: :string, nullable: true },
                      direction: { type: :string, nullable: true }
                    }
                  }
                },
                required: [:pagination]
              }
            },
            required: [:data, :meta]
          },
          TransactionResponse: {
            type: :object,
            properties: {
              data: { "$ref" => "#/components/schemas/Transaction" },
              message: { type: :string, description: "Optional success message" }
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
