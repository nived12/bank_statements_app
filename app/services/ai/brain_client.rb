# app/services/ai/brain_client.rb
module Ai
  class BrainClient < ApplicationService
    include HTTParty
    base_uri ENV.fetch("VITTIO_BRAIN_URL", "http://localhost:8000")

    def initialize(raw_text:, user_id:)
      @raw_text = raw_text
      @user_id = user_id
      @api_key = ENV.fetch("BRAIN_API_KEY", "vittio_secret_dev_key")
    end

    def call
      response = self.class.post(
        "/audit",
        headers: {
          "Content-Type" => "application/json",
          "X-Brain-Token" => @api_key
        },
        body: {
          raw_text: @raw_text,
          user_id: @user_id
        }.to_json,
        timeout: 60
      )

      if response.success?
        success(response.parsed_response)
      else
        errors.add(:base, "Brain API Error: #{response.code} - #{response.body}")
        failure
      end
    rescue StandardError => e
      errors.add(:base, "Failed to connect to Vittio Brain: #{e.message}")
      failure
    end
  end
end
