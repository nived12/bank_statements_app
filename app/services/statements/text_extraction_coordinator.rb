require "open3"
require "shellwords"
require "timeout"

module Statements
  class TextExtractionCoordinator < ApplicationService
    DEFAULT_MARKITDOWN_COMMAND = "markitdown".freeze
    DEFAULT_MARKITDOWN_TIMEOUT = 45

    def initialize(pdf_path:, password: nil, mode: :prefer_native)
      super()
      @pdf_path = pdf_path
      @password = password
      @mode = mode
    end

    def call
      case mode
      when :native_only
        success(extract_native_text)
      when :markitdown_only
        success(extract_markitdown_text)
      when :prefer_native
        success(extract_native_text || extract_markitdown_text)
      else
        failure("Unknown text extraction mode: #{mode}")
      end
    end

    def self.markitdown_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("MARKITDOWN_ENABLED", false))
    end

    private

    attr_reader :pdf_path, :password, :mode

    def extract_native_text
      text = TextExtractor.extract_text_layer(pdf_path, password: password)
      return unless TextExtractor.valid_text?(text)

      Rails.logger.info("Native text extraction successful (#{text.length} chars)")
      {
        text: text,
        format: "plain_text",
        source: "native_pdf_text",
        usable_for_parser: true
      }
    end

    def extract_markitdown_text
      unless self.class.markitdown_enabled?
        Rails.logger.info("MarkItDown fallback disabled")
        return
      end

      command = Shellwords.split(ENV.fetch("MARKITDOWN_COMMAND", DEFAULT_MARKITDOWN_COMMAND))
      stdout, stderr, status = run_markitdown(command + [pdf_path])

      unless status&.success?
        Rails.logger.warn(
          "MarkItDown failed: #{stderr.to_s.lines.first(3).join(" ").strip.presence || "unknown error"}"
        )
        return
      end

      text = normalize_markitdown_output(stdout)
      unless valid_markitdown_output?(text)
        Rails.logger.info("MarkItDown returned empty or unusable output")
        return
      end

      Rails.logger.info("MarkItDown text extraction successful (#{text.length} chars)")
      {
        text: text,
        format: "markdown",
        source: "markitdown_pdf",
        usable_for_parser: false
      }
    rescue Errno::ENOENT => e
      Rails.logger.warn("MarkItDown unavailable: #{e.message}")
      nil
    rescue Timeout::Error
      Rails.logger.warn("MarkItDown timed out after #{markitdown_timeout_seconds}s")
      nil
    end

    def run_markitdown(command)
      Timeout.timeout(markitdown_timeout_seconds) do
        Open3.capture3(*command)
      end
    end

    def markitdown_timeout_seconds
      ENV.fetch("MARKITDOWN_TIMEOUT_SECONDS", DEFAULT_MARKITDOWN_TIMEOUT).to_i
    end

    def normalize_markitdown_output(text)
      normalized = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      normalized = normalized.delete("\u0000")
      normalized = normalized.gsub(/\r\n?/, "\n")
      normalized = normalized.gsub(/\A```(?:markdown|md)?\s*/i, "")
      normalized = normalized.gsub(/\s*```\s*\z/, "")
      normalized = normalized.gsub(/\n{3,}/, "\n\n")
      normalized.strip
    end

    def valid_markitdown_output?(text)
      return false if text.blank?
      return true if TextExtractor.valid_text?(text)

      text.match?(/^\s*#/m) || text.match?(/^\s*\|.+\|/m)
    end
  end
end
