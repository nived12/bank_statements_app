# frozen_string_literal: true

module Ai
  class GeminiClient < ApplicationService
    attr_reader :client, :model

    def initialize(model: ENV["GEMINI_MODEL"])
      super()
      @model = model || "gemini-2.0-flash-lite"
      @client = initialize_client
    end

    def chat(prompt, options = {})
      Rails.logger.info("🤖 Gemini: Sending request to #{@model}")

      begin
        # Use simple string format for now
        result = @client.generate_content({ contents: { role: "user", parts: { text: prompt } } })

        # Extract text from response
        text = extract_text_from_response(result)

        Rails.logger.info("🤖 Gemini: Response received, length: #{text&.length || 0} chars")
        text
      rescue => e
        Rails.logger.error("🤖 Gemini: Error - #{e.class}: #{e.message}")
        raise e
      end
    end

    def generate_content_with_image(image_url, prompt, options = {})
      Rails.logger.info("🤖 Gemini: Sending image request to #{@model}")

      begin
        # Format prompt with image
        contents = format_prompt_with_image(image_url, prompt)

        # Generate content using Gemini
        result = @client.generate_content(contents)

        # Extract text from response
        text = extract_text_from_response(result)

        Rails.logger.info("🤖 Gemini: Image response received, length: #{text&.length || 0} chars")
        text
      rescue => e
        Rails.logger.error("🤖 Gemini: Image Error - #{e.class}: #{e.message}")
        raise e
      end
    end


    private

    def initialize_client
      require "gemini-ai"

      # Configure Gemini client
      Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: ENV["GEMINI_API_KEY"]
        },
        options: {
          model: @model,
          connection: {
            request: {
              timeout: 60,
              open_timeout: 10,
              read_timeout: 60,
              write_timeout: 10
            }
          }
        }
      )
    end

    def format_prompt(prompt)
      if prompt.is_a?(String)
        {
          contents: [
            {
              role: "user",
              parts: [ { text: prompt } ]
            }
          ]
        }
      else
        prompt
      end
    end

    def format_prompt_with_image(image_url, text_prompt)
      {
        contents: [
          {
            role: "user",
            parts: [
              { text: text_prompt },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: fetch_image_data(image_url)
                }
              }
            ]
          }
        ]
      }
    end

    def fetch_image_data(image_url)
      # For now, we'll use a placeholder
      # In production, you'd fetch the actual image data
      "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
    end


    def extract_text_from_response(result)
      Rails.logger.info("🔍 DEBUG: Extracting text from result: #{result.class}")
      Rails.logger.info("🔍 DEBUG: Result structure: #{result.inspect[0..200]}...")

      return nil unless result

      # Handle Hash response format (direct response)
      if result.is_a?(Hash) && result["candidates"]
        candidates = result["candidates"]
        if candidates && candidates.first
          content = candidates.first["content"]
          if content && content["parts"] && content["parts"].first
            text = content["parts"].first["text"]
            Rails.logger.info("🔍 DEBUG: Extracted text: #{text[0..100]}...")
            return text
          end
        end
      end

      # Handle Array response format (streaming)
      if result.is_a?(Array) && result.first
        candidates = result.first["candidates"]
        if candidates && candidates.first
          content = candidates.first["content"]
          if content && content["parts"] && content["parts"].first
            text = content["parts"].first["text"]
            Rails.logger.info("🔍 DEBUG: Extracted text: #{text[0..100]}...")
            return text
          end
        end
      end

      Rails.logger.warn("🔍 DEBUG: Could not extract text from result")
      nil
    end
  end
end
