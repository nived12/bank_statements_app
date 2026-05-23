module Ai
  class Client
    include Ai::Concerns::GeminiHttpClient

    # mode: :default | :pro | :vision
    #   :default → ENV["AI_MODEL"]
    #   :pro     → ENV["PRO_AI_MODEL"] (falls back to ENV["AI_MODEL"] if unset)
    #   :vision  → ENV["VISION_AI_MODEL"]
    # vision: true is kept as a backwards-compat alias for mode: :vision.
    def initialize(provider: ENV["AI_PROVIDER"], api_key: ENV["AI_API_KEY"], model: nil, vision: false, mode: nil)
      @provider = provider || "gemini"
      @api_key  = api_key
      @mode     = (mode || (vision ? :vision : :default)).to_sym
      @model    = model || resolve_model(@provider, @mode)
    end

    attr_reader :model, :mode

    def chat(prompt)
      raise "Missing AI_API_KEY" if @api_key.to_s.empty?

      case @provider.downcase
      when "openai"  then chat_openai(prompt)
      when "gemini"  then chat_gemini(prompt)
      else raise "Unsupported provider: #{@provider}. Supported: openai, gemini"
      end
    end

    # Tool-calling loop for Gemini (up to max_iterations round trips).
    # tools_schema: array of Gemini FunctionDeclaration hashes
    # on_tool_call: proc(name, args) -> result_hash
    # Returns same hash as #chat: { text:, usage: }
    def chat_with_tools(prompt, tools_schema:, on_tool_call:, max_iterations: 3)
      raise "Missing AI_API_KEY" if @api_key.to_s.empty?
      raise "Gemini only for tool calling" unless @provider.downcase == "gemini"

      model_name = @model
      url        = gemini_api_url(model_name)

      contents = [ { role: "user", parts: [ { text: prompt } ] } ]
      total_usage = { prompt_token_count: 0, candidates_token_count: 0, total_token_count: 0 }
      tools_called = []

      max_iterations.times do
        payload = {
          contents: contents,
          tools: [ { function_declarations: tools_schema } ]
        }

        response = gemini_post(url, api_key: @api_key, payload: payload)
        unless response.success?
          error_msg = response.parsed_response&.dig("error", "message") || "[body redacted]"
          raise "Gemini API error: #{response.code} - #{error_msg}"
        end

        accumulate_usage!(total_usage, response.dig("usageMetadata"))

        candidate = response.dig("candidates", 0)
        parts      = candidate&.dig("content", "parts") || []

        # Append model turn
        contents << { role: "model", parts: parts }

        function_calls = parts.select { |p| p["functionCall"] }

        # If no function calls, extract text and return
        if function_calls.empty?
          text = parts.map { |p| p["text"].to_s }.join.strip
          text = I18n.t("assistant.responses.fallback") if text.blank?
          return { text: text, usage: total_usage, tools_called: tools_called }
        end

        # Execute all function calls and build tool response turn
        tool_results = function_calls.map do |part|
          fn   = part["functionCall"]
          name = fn["name"]
          args = (fn["args"] || {}).transform_keys(&:to_sym)
          tools_called << { "name" => name, "args" => args.transform_keys(&:to_s) }

          begin
            result = on_tool_call.call(name, args)
          rescue => e
            Rails.logger.warn("Tool #{name} failed: #{e.message}")
            result = { error: "Tool #{name} failed: #{e.message}" }
          end

          { functionResponse: { name: name, response: { result: result } } }
        end

        contents << { role: "user", parts: tool_results }
      end

      # Exhausted iterations — return what we have
      last_text_part = contents.reverse.find { |c| c[:role] == "model" || c["role"] == "model" }
      text = last_text_part&.dig(:parts, 0, :text) ||
             last_text_part&.dig("parts", 0, "text") || ""
      text = I18n.t("assistant.responses.fallback") if text.blank?
      { text: text, usage: total_usage, tools_called: tools_called }
    end

    private

    def resolve_model(provider, mode)
      return nil unless provider&.downcase == "gemini"

      case mode
      when :vision
        ENV["VISION_AI_MODEL"].presence || "gemini-3-flash-preview"
      when :pro
        ENV["PRO_AI_MODEL"].presence || ENV["AI_MODEL"].presence || "gemini-3.1-flash-lite"
      else
        ENV["AI_MODEL"].presence || "gemini-3.1-flash-lite"
      end
    end

    def accumulate_usage!(total, meta)
      return unless meta

      total[:prompt_token_count]     += meta["promptTokenCount"].to_i
      total[:candidates_token_count] += meta["candidatesTokenCount"].to_i
      total[:total_token_count]      += meta["totalTokenCount"].to_i
    end

    def chat_openai(prompt)
      uri = URI.parse("https://api.openai.com/v1/chat/completions")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"] = "application/json"
      request_body = {
        model: @model || "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a precise JSON API. Return ONLY strict JSON, no markdown, no prose." },
          { role: "user", content: prompt }
        ]
      }

      if ENV["AI_TEMPERATURE"].present? && ENV["AI_TEMPERATURE"].to_f > 0.0
        request_body[:temperature] = ENV["AI_TEMPERATURE"].to_f
      end

      req.body = request_body.to_json

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.open_timeout = 45
      http.read_timeout = 180

      res = http.request(req)
      raise "AI HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      data    = JSON.parse(res.body)
      content = data.dig("choices", 0, "message", "content").to_s.strip

      usage_data = data.dig("usage")
      usage = if usage_data
        {
          prompt_token_count: usage_data["prompt_tokens"],
          candidates_token_count: usage_data["completion_tokens"],
          total_token_count: usage_data["total_tokens"]
        }
      else
        {}
      end

      { text: content, usage: usage }
    end

    def chat_gemini(prompt)
      model_name = @model
      url        = gemini_api_url(model_name)
      payload    = { contents: [ { parts: [ { text: prompt } ] } ] }

      begin
        response = gemini_post(url, api_key: @api_key, payload: payload)

        unless response.success?
          error_message = response.parsed_response&.dig("error", "message") || "[body redacted]"
          Rails.logger.error("Gemini REST API Error: #{response.code} - #{error_message}")
          raise "Gemini API error: #{response.code} - #{error_message}"
        end

        text = response.dig("candidates", 0, "content", "parts", 0, "text")

        usage_metadata = response.dig("usageMetadata")
        usage = if usage_metadata
          {
            prompt_token_count: usage_metadata["promptTokenCount"],
            candidates_token_count: usage_metadata["candidatesTokenCount"],
            total_token_count: usage_metadata["totalTokenCount"]
          }
        else
          {}
        end

        { text: text, usage: usage }
      rescue HTTParty::Error => e
        Rails.logger.error("Gemini HTTP error: #{e.message}")
        raise "Gemini API HTTP error: #{e.message}"
      rescue StandardError => e
        Rails.logger.error("Gemini unexpected error: #{e.message}")
        raise e
      end
    end
  end
end
