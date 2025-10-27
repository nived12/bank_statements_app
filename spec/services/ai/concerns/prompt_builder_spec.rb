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
  let(:categories) do
    # Use the default categories created by the User callback
    # Add a child category to one of the existing parent categories
    servicios = user.categories.find_by(name: "Servicios")
    create(:category, user: user, name: "Bancarios", parent: servicios)

    # Return the actual ActiveRecord::Relation
    Category.where(user: user).where(parent_id: nil).includes(:children).order(:name)
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
      expect(prompt).to include("**CATEGORIES (use EXACT names):**")
      expect(prompt).to include("**TRANSACTIONS TO CATEGORIZE (one per line):**")
      expect(prompt).to include("**CRITICAL INSTRUCTIONS:**")
    end

    it "includes category taxonomy" do
      result = builder.build_categorization_prompt(raw_text, categories)

      expect(result.success?).to be true
      prompt = result.payload
      expect(prompt).to include('"name":"Ingresos"')
      expect(prompt).to include('"name":"Servicios"')
      expect(prompt).to include('"Bancarios"')
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
      expect(prompt).to include('"category": "category name"')
      expect(prompt).to include('"sub_category": "subcategory name or null"')
      expect(prompt).to include('"transaction_type": "income", "variable_expense", or "fixed_expense"')
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

      expect(result.success?).to be true
      expect(result.payload).to include("Sin Categorizar")
    end
  end

  describe "#taxonomy_payload" do
    it "builds a mapping of category names to IDs" do
      result = builder.send(:taxonomy_payload, categories)

      expect(result).to be_an(Array)
      expect(result.length).to be > 0 # Has parent categories

      # Find the categories in the result
      ingresos_cat = result.find { |cat| cat[:name] == "Ingresos" }

      expect(ingresos_cat).to be_present
      expect(ingresos_cat[:subcategories]).to include("Freelance", "Inversiones", "Otros Ingresos")
    end

    it "handles categories with subcategories" do
      # Use the default categories (which have subcategories by default)
      categories_with_children = Category.where(user: user).where(parent_id: nil).includes(:children).order(:name)

      result = builder.send(:taxonomy_payload, categories_with_children)

      expect(result).to be_an(Array)
      expect(result.length).to be > 0 # Has parent categories

      ingresos_cat = result.find { |cat| cat[:name] == "Ingresos" }
      expect(ingresos_cat).to be_present
      expect(ingresos_cat[:subcategories]).to include("Freelance", "Inversiones", "Otros Ingresos")
    end

    it "handles nil categories gracefully" do
      result = builder.send(:taxonomy_payload, nil)

      expect(result).to eq([ { name: "Sin Categorizar", subcategories: [] } ])
    end

    it "handles categories without required methods gracefully" do
      # Use the default categories plus one additional test category
      create(:category, user: user, name: "TestCategory", parent: nil)
      valid_categories = Category.where(user: user).where(parent_id: nil).includes(:children).order(:name)

      result = builder.send(:taxonomy_payload, valid_categories)

      expect(result).to be_an(Array)
      expect(result.length).to be > 0 # Has categories including TestCategory

      # Find our test category in the result
      test_cat = result.find { |cat| cat[:name] == "TestCategory" }
      expect(test_cat).to be_present
      expect(test_cat[:subcategories]).to eq([])
    end
  end
end
