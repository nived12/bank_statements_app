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

      content = @client.chat(prompt)
      json = JSON.parse(content)
      normalize!(json)
      json
    rescue => e
      Rails.logger.error("Ai::PostProcessor error: #{e.message}")
      nil
    end

    private

    def normalize!(json)
      json["transactions"] ||= []
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

        # cleanup legacy
        t.delete("type")
        t.delete("fixed_or_variable")

        t["category"] ||= "Uncategorized"
      end
    end
  end
end
