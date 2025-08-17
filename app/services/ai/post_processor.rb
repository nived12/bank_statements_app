# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor
    def initialize(client: Ai::Client.new)
      @client = client
    end

    def call(raw_text:, bank_name:, account_number:, categories:)
      prompt = Ai::PromptBuilders::StatementToJson
        .new(bank_name: bank_name, account_number: account_number, categories: categories)
        .build(raw_text: raw_text)

      Rails.logger.info("AI: Sending prompt to #{ENV['AI_PROVIDER']} with #{categories.count} categories")

      content = @client.chat(prompt)

      Rails.logger.info("AI: Received response, length: #{content.length}")

      json = JSON.parse(content)
      normalize!(json)

      Rails.logger.info("AI: Successfully processed #{json['transactions']&.count || 0} transactions")
      json
    rescue => e
      Rails.logger.error("Ai::PostProcessor error: #{e.message}")
      Rails.logger.error("AI: Raw text length: #{raw_text.length}")
      Rails.logger.error("AI: Categories count: #{categories.count}")
      Rails.logger.error("AI: Error backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    end

    private

    def normalize!(json)
      json["transactions"] ||= []

      # Normalize balances to numbers
      json["opening_balance"] = normalize_balance(json["opening_balance"])
      json["closing_balance"] = normalize_balance(json["closing_balance"])

      json["transactions"].each do |t|
        # amount
        t["amount"] =
          case t["amount"]
          when String then t["amount"].to_s.tr(",", "").to_f
          else t["amount"].to_f
          end

        # transaction_type (fallback)
        unless %w[income fixed_expense variable_expense].include?(t["transaction_type"].to_s)
          t["transaction_type"] = t["amount"].to_f < 0 ? "variable_expense" : "income"
        end

        # bank_entry_type
        t["bank_entry_type"] =
          case t["bank_entry_type"].to_s.downcase.strip
          when "credit", "cr" then "credit"
          when "debit", "dr"  then "debit"
          else nil
          end

        # confidences
        %w[confidence category_confidence transaction_type_confidence].each do |k|
          t[k] = t[k].to_f.clamp(0.0, 1.0) if t.key?(k)
        end

        t["category"] ||= "Sin Categorizar"
      end
    end

    def normalize_balance(balance)
      return nil if balance.nil?

      case balance
      when String
        # Remove commas and convert to float
        balance.to_s.tr(",", "").to_f
      when Numeric
        balance.to_f
      else
        balance.to_f
      end
    end
  end
end
