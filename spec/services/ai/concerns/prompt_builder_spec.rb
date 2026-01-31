require 'rails_helper'

RSpec.describe Ai::Concerns::PromptBuilder do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include Ai::Concerns::PromptBuilder

      def initialize
        @errors = ActiveModel::Errors.new(self)
      end

      def errors
        @errors
      end

      def success(payload = nil)
        OpenStruct.new(success?: true, payload: payload)
      end

      def failure
        OpenStruct.new(success?: false)
      end
    end
  end

  let(:builder) { test_class.new }
  let(:user) { create(:user) }
  let(:categories) { user.categories }

  describe "#build_categorization_prompt" do
    let(:raw_text) { "SPEI ENVIADO\nDEPOSITO NOMINA" }

    it "builds a prompt with the correct structure" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("You are a transaction categorizer")
      expect(prompt).to include("**INPUT FORMAT: Each line below represents a separate transaction.**")
      expect(prompt).to include("**REQUIRED FORMAT:**")
      expect(prompt).to include("**CATEGORIES (use the id field, not the name):**")
      expect(prompt).to include("**TRANSACTIONS TO CATEGORIZE (one per line):**")
      expect(prompt).to include("**CRITICAL INSTRUCTIONS:**")
    end

    it "includes category taxonomy with IDs" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include('"id":')
      expect(prompt).to include('"name":"Ingresos"')
      expect(prompt).to include('"name":"Servicios"')
    end

    it "includes required format instructions with category_id" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include('"category_id": 123')
      expect(prompt).to include('"transaction_type": "income", "variable_expense", or "fixed_expense"')
    end

    it "includes critical instructions" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("Count the number of lines above")
      expect(prompt).to include("Create exactly that many transactions")
      expect(prompt).to include("Each line = one transaction")
      expect(prompt).to include("Use category_id (the numeric ID from the categories list)")
    end

    it "handles nil raw_text gracefully" do
      result = builder.build_categorization_prompt(nil, categories)

      expect(result.success?).to be true
      expect(result.payload).to include("TRANSACTIONS TO CATEGORIZE (one per line):")
    end

    it "handles nil categories gracefully" do
      result = builder.build_categorization_prompt(raw_text, nil)

      expect(result.success?).to be true
      expect(result.payload).to include("[]")
    end
  end

  describe "#taxonomy_payload" do
    it "builds a list of categories with IDs" do
      result = builder.send(:taxonomy_payload, categories)

      expect(result).to be_an(Array)
      expect(result.length).to be > 0

      first_category = result.first
      expect(first_category).to have_key(:id)
      expect(first_category).to have_key(:name)
    end

    it "includes category IDs for lookup" do
      result = builder.send(:taxonomy_payload, categories)

      ingresos_cat = result.find { |cat| cat[:name] == "Ingresos" }
      expect(ingresos_cat).to be_present
      expect(ingresos_cat[:id]).to be_a(Integer)
    end

    it "handles nil categories gracefully" do
      result = builder.send(:taxonomy_payload, nil)

      expect(result).to eq([])
    end

    it "handles empty categories gracefully" do
      result = builder.send(:taxonomy_payload, [])

      expect(result).to eq([])
    end
  end
end
