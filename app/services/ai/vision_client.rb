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

    # A read timeout is the one failure here that is worth retrying: the extractor
    # turns every exception into a permanent `status: error`, so the job completes
    # and no retry mechanism upstream can ever fire. One transient stall used to
    # kill a statement outright and burn the user's upload slot.
    #
    # Both attempts keep the original 180s. Lowering the first attempt was considered
    # and rejected: production has 75 statements with a 100% success rate and zero
    # timeouts, so a shorter budget could only manufacture failures that do not exist
    # today. The duration data could not justify it either — it contains a negative
    # duration and a 20-hour outlier, so every percentile above the median is junk.
    # This retry is therefore pure upside: it fires only where today's outcome is
    # already a hard failure.
    #
    # Only timeouts. ApiError is already billed and usually deterministic (a
    # MAX_TOKENS truncation would just spend the money again), and the rest are
    # permanent — a missing Ghostscript binary will not fix itself in four seconds.
    FIRST_ATTEMPT_TIMEOUT = 180
    RETRY_TIMEOUT = 180
    RETRY_BACKOFF = 4
    RETRYABLE_ERRORS = [Net::ReadTimeout, Net::OpenTimeout].freeze

    def initialize(api_key: ENV["AI_API_KEY"], model: ENV["VISION_AI_MODEL"] || ENV["AI_MODEL"])
      @api_key = api_key
      @model = model.presence || "gemini-3-flash-preview"

      raise ApiError, "AI_API_KEY is required" if @api_key.blank?
    end

    def analyze_document(image_paths, prompt)
      raise ArgumentError, "Image paths cannot be empty" if image_paths.blank?
      raise ArgumentError, "Prompt cannot be empty" if prompt.blank?

      parts = build_request_parts(prompt, image_paths)
      extract_response(request_with_retry(parts))
    end

    private

    def request_with_retry(parts)
      attempts = 0

      begin
        attempts += 1
        post_to_gemini(parts, timeout: attempts == 1 ? FIRST_ATTEMPT_TIMEOUT : RETRY_TIMEOUT)
      rescue *RETRYABLE_ERRORS => e
        raise if attempts > 1

        # Logged rather than counted silently: one incident is not a timeout rate,
        # and this is the only way to find out what the real one is.
        Rails.logger.warn(
          "Vision API #{e.class} after #{FIRST_ATTEMPT_TIMEOUT}s — retrying once with #{RETRY_TIMEOUT}s. " \
          "Note the first attempt may still have been billed."
        )
        sleep(RETRY_BACKOFF)
        retry
      end
    end

    def post_to_gemini(parts, timeout:)
      gemini_post(
        gemini_api_url(@model),
        api_key: @api_key,
        payload: {
          contents: [{ parts: parts }],
          generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS }
        },
        timeout: timeout
      )
    end

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
