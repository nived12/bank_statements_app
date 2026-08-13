# app/services/ai/vision_client.rb
require "base64"

module Ai
  class VisionClient
    include Ai::Concerns::GeminiHttpClient

    # Carries usage when the call was billed but produced nothing usable, so the
    # caller can still record what it paid for.
    class ApiError < StandardError
      attr_reader :usage

      def initialize(message = nil, usage: nil)
        super(message)
        @usage = usage
      end
    end

    MIME_TYPES = {
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".webp" => "image/webp"
    }.freeze

    # Thinking tokens come out of this budget too, so the usable JSON room is
    # whatever the model does not spend thinking. 65,536 is the model ceiling.
    MAX_OUTPUT_TOKENS = ENV.fetch("GEMINI_MAX_OUTPUT_TOKENS", 65_536).to_i

    def initialize(api_key: ENV["AI_API_KEY"], model: ENV["VISION_AI_MODEL"] || ENV["AI_MODEL"])
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
          generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS }
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
      usage_metadata = parsed["usageMetadata"] || {}

      # Anything but STOP means the text is a fragment; returning it just moves
      # the failure downstream into an unexplained JSON parse error.
      finish_reason = parsed.dig("candidates", 0, "finishReason")
      Rails.logger.info("Gemini finishReason: #{finish_reason}") if finish_reason

      usage = usage_from(usage_metadata)

      if finish_reason.present? && finish_reason != "STOP"
        raise ApiError.new(
          "Gemini stopped early (finishReason: #{finish_reason}, output " \
          "#{usage[:candidates_token_count] || 0} + thinking " \
          "#{usage[:thoughts_token_count] || 0} of #{MAX_OUTPUT_TOKENS} max)",
          usage: usage
        )
      end

      text = parsed.dig("candidates", 0, "content", "parts", 0, "text")
      raise ApiError.new("No text content in response", usage: usage) if text.blank?

      { text: text, usage: usage }
    end

    def usage_from(usage_metadata)
      {
        prompt_token_count: usage_metadata["promptTokenCount"],
        candidates_token_count: usage_metadata["candidatesTokenCount"],
        thoughts_token_count: usage_metadata["thoughtsTokenCount"],
        total_token_count: usage_metadata["totalTokenCount"]
      }
    end
  end
end
