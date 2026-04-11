# app/services/ai/vision_client.rb
require "base64"

module Ai
  class VisionClient
    include Ai::Concerns::GeminiHttpClient

    class ApiError < StandardError; end

    MIME_TYPES = {
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".webp" => "image/webp"
    }.freeze

    def initialize(api_key: ENV["AI_API_KEY"], model: ENV["AI_MODEL"])
      @api_key = api_key
      @model = model.presence || "gemini-3-flash-preview"

      raise ApiError, "AI_API_KEY is required" if @api_key.blank?
    end

    def analyze_document(image_paths, prompt)
      raise ArgumentError, "Image paths cannot be empty" if image_paths.blank?
      raise ArgumentError, "Prompt cannot be empty" if prompt.blank?

      parts = build_request_parts(prompt, image_paths)
      response = gemini_post(
        gemini_api_url(@model),
        api_key: @api_key,
        payload: {
          contents: [{ parts: parts }],
          generationConfig: {
            maxOutputTokens: 32768,
            thinkingConfig: { thinkingBudget: 0 }
          }
        }
      )
      extract_response(response)
    end

    private

    def build_request_parts(prompt, image_paths)
      parts = [{ text: prompt }]

      image_paths.each do |path|
        unless File.exist?(path)
          Rails.logger.warn("Image file not found: #{path}")
          next
        end

        parts << {
          inline_data: {
            mime_type: MIME_TYPES.fetch(File.extname(path).downcase, "image/jpeg"),
            data: Base64.strict_encode64(File.read(path))
          }
        }
      end

      parts
    end

    def extract_response(response)
      unless response.success?
        error_message = response.parsed_response&.dig("error", "message") || response.body
        raise ApiError, "Gemini API error (#{response.code}): #{error_message}"
      end

      parsed = response.parsed_response
      finish_reason = parsed.dig("candidates", 0, "finishReason")
      Rails.logger.info("Gemini finishReason: #{finish_reason}") if finish_reason
      Rails.logger.warn("Gemini stopped early: #{finish_reason}") if finish_reason && finish_reason != "STOP"

      text = parsed.dig("candidates", 0, "content", "parts", 0, "text")
      raise ApiError, "No text content in response" if text.blank?

      usage_metadata = parsed["usageMetadata"] || {}
      {
        text: text,
        usage: {
          prompt_token_count: usage_metadata["promptTokenCount"],
          candidates_token_count: usage_metadata["candidatesTokenCount"],
          total_token_count: usage_metadata["totalTokenCount"]
        }
      }
    end
  end
end
