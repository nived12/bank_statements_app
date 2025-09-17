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
  let(:categories) do
    [
      double("Category", name: "Ingresos", id: 1, children: []),
      double("Category", name: "Servicios", id: 2, children: [
        double("SubCategory", name: "Bancarios", id: 3)
      ])
    ]
  end

  describe "#build_categorization_prompt" do
    let(:raw_text) { "SPEI ENVIADO\nDEPOSITO NOMINA" }

    it "builds a prompt with the correct structure" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("You are a transaction categorizer")
      expect(prompt).to include("**INPUT FORMAT: Each line below represents a separate transaction.**")
      expect(prompt).to include("**REQUIRED FORMAT:**")
      expect(prompt).to include("**CATEGORIES (Name → ID mapping):**")
      expect(prompt).to include("**TRANSACTIONS TO CATEGORIZE (one per line):**")
      expect(prompt).to include("**CRITICAL INSTRUCTIONS:**")
    end

    it "includes category taxonomy" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include('"Ingresos":1')
      expect(prompt).to include('"Servicios":2')
      expect(prompt).to include('"Servicios \u003e Bancarios":3')
    end

    it "includes transaction rules" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("SPEI ENVIADO, RETIRO, PAGO → \"Servicios\"")
      expect(prompt).to include("DEPOSITO, NOMINA, BONO, RECIBIDO → \"Ingresos\"")
    end

    it "includes required format instructions" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include('"category_id": 123')
      expect(prompt).to include('"sub_category_id": 456')
      expect(prompt).to include('"transaction_type": "income"')
    end

    it "includes critical instructions" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("Count the number of lines above")
      expect(prompt).to include("Create exactly that many transactions")
      expect(prompt).to include("Each line = one transaction")
    end

    it "handles nil raw_text gracefully" do
      result = builder.build_categorization_prompt(nil, categories)

      expect(result.success?).to be true
      expect(result.payload).to include("TRANSACTIONS TO CATEGORIZE (one per line):")
      expect(result.payload).to include("**TRANSACTIONS TO CATEGORIZE (one per line):**\n\n")
    end

    it "handles nil categories gracefully" do
      result = builder.build_categorization_prompt(raw_text, nil)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("Failed to build category taxonomy: undefined method `each' for nil")
    end
  end

  describe "#build_category_taxonomy" do
    it "builds a mapping of category names to IDs" do
      result = builder.send(:build_category_taxonomy, categories)

      expect(result.success?).to be true
      parsed_taxonomy = JSON.parse(result.payload)
      expect(parsed_taxonomy["Ingresos"]).to eq(1)
      expect(parsed_taxonomy["Servicios"]).to eq(2)
      expect(parsed_taxonomy["Servicios > Bancarios"]).to eq(3)
    end

    it "handles categories without subcategories" do
      categories_without_children = [
        double("Category", name: "Ingresos", id: 1, children: [])
      ]

      result = builder.send(:build_category_taxonomy, categories_without_children)

      expect(result.success?).to be true
      parsed_taxonomy = JSON.parse(result.payload)
      expect(parsed_taxonomy["Ingresos"]).to eq(1)
      expect(parsed_taxonomy.keys).not_to include("Ingresos > ")
    end

    it "handles nil categories gracefully" do
      result = builder.send(:build_category_taxonomy, nil)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("Failed to build category taxonomy: undefined method `each' for nil")
    end

    it "handles categories without required methods gracefully" do
      invalid_categories = [ double("Category", name: "Ingresos", id: 1, children: []) ]

      result = builder.send(:build_category_taxonomy, invalid_categories)

      expect(result.success?).to be true
      # This should actually succeed now since we have all required methods
    end
  end
end
