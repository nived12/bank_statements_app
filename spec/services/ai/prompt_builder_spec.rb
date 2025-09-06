# spec/services/ai/prompt_builder_spec.rb
require "rails_helper"

RSpec.describe Ai::PromptBuilder do
  let(:builder) { described_class.new }
  let(:categories) do
    [
      double("Category", name: "Ingresos", id: 1, children: []),
      double("Category", name: "Servicios", id: 2, children: [
        double("Subcategory", name: "Entretenimiento", id: 3)
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
      expect(prompt).to include("SPEI ENVIADO")
      expect(prompt).to include("DEPOSITO NOMINA")
      expect(prompt).to include("Ingresos")
      expect(prompt).to include("Servicios")
    end

    it "includes category taxonomy" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("Ingresos")
      expect(prompt).to include("Servicios")
      expect(prompt).to include("Servicios \\u003e Entretenimiento")
    end

    it "includes transaction rules" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("SPEI ENVIADO")
      expect(prompt).to include("DEPOSITO")
      expect(prompt).to include("NOMINA")
      expect(prompt).to include("variable_expense")
      expect(prompt).to include("income")
    end

    it "includes required format instructions" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("description")
      expect(prompt).to include("category")
      expect(prompt).to include("transaction_type")
      expect(prompt).to include("confidence")
    end

    it "includes critical instructions" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include("Count the number of lines above")
      expect(prompt).to include("Create exactly that many transactions")
      expect(prompt).to include("Each line = one transaction")
    end

    it "returns failure for invalid raw_text" do
      result = builder.build_categorization_prompt(nil, categories)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("raw_text must be a String and categories must respond to :each")
    end

    it "returns failure for invalid categories" do
      result = builder.build_categorization_prompt(raw_text, nil)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("raw_text must be a String and categories must respond to :each")
    end
  end

  describe "#build_category_taxonomy" do
    it "builds a mapping of category names to IDs" do
      result = builder.send(:build_category_taxonomy, categories)

      expect(result.success?).to be true
      parsed_taxonomy = JSON.parse(result.payload)
      expect(parsed_taxonomy["Ingresos"]).to eq(1)
      expect(parsed_taxonomy["Servicios"]).to eq(2)
      expect(parsed_taxonomy["Servicios > Entretenimiento"]).to eq(3)
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

    it "returns failure for invalid categories" do
      result = builder.send(:build_category_taxonomy, nil)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("categories must respond to :each")
    end

    it "returns failure for categories without required methods" do
      invalid_categories = [ double("Category", name: "Ingresos") ]

      result = builder.send(:build_category_taxonomy, invalid_categories)

      expect(result.success?).to be false
      expect(builder.errors[:base]).to include("Each category must respond to :name, :id, and :children")
    end
  end
end
