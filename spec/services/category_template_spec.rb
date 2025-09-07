require 'rails_helper'

RSpec.describe CategoryTemplate do
  describe '.create_categories_for_user' do
    it 'creates all parent categories' do
      user = create(:user)
      described_class.create_categories_for_user(user)

      parent_categories = user.categories.where(parent_id: nil).pluck(:name)
      expected_parents = [
        "Comida", "Transporte", "Entretenimiento", "Compras",
        "Salud", "Educación", "Servicios", "Ingresos", "Gastos Varios",
        "Transferencias", "Comisiones"
      ]

      expect(parent_categories).to match_array(expected_parents)

      # Verify total count is correct
      expect(user.categories.count).to eq(43)
    end

    it 'creates the correct number of total categories' do
      user = create(:user)

      # The user factory automatically creates categories via after_create callback
      # Due to test isolation issues, the user may already have categories
      initial_count = user.categories.count
      expect(initial_count).to be > 0

      # Test that calling the service again doesn't create duplicates (idempotency)
      expect {
        described_class.create_categories_for_user(user)
      }.not_to change { user.categories.count }

      # The user should have exactly 43 categories (11 parent-level + 32 children)
      # 8 parent categories + 3 additional categories + 32 child categories = 43 total
      expect(user.categories.count).to eq(43)
    end

    context 'food category hierarchy' do
      it 'creates food parent category' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        food_category = user.categories.find_by(name: "Comida")
        expect(food_category).to be_present
        expect(food_category.parent_id).to be_nil
      end

      it 'creates food subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        food_category = user.categories.find_by(name: "Comida")
        subcategories = food_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Restaurantes", "Supermercado", "Delivery", "Bebidas"
        ])
      end
    end

    context 'transport category hierarchy' do
      it 'creates transport parent category' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        transport_category = user.categories.find_by(name: "Transporte")
        expect(transport_category).to be_present
        expect(transport_category.parent_id).to be_nil
      end

      it 'creates transport subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        transport_category = user.categories.find_by(name: "Transporte")
        subcategories = transport_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Gasolina", "Transporte Público", "Mantenimiento", "Estacionamiento"
        ])
      end
    end

    context 'entertainment category hierarchy' do
      it 'creates entertainment subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        entertainment_category = user.categories.find_by(name: "Entretenimiento")
        subcategories = entertainment_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Cine", "Deportes", "Viajes", "Hobbies"
        ])
      end
    end

    context 'shopping category hierarchy' do
      it 'creates shopping subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        shopping_category = user.categories.find_by(name: "Compras")
        subcategories = shopping_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Ropa", "Tecnología", "Hogar", "Cosméticos"
        ])
      end
    end

    context 'health category hierarchy' do
      it 'creates health subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        health_category = user.categories.find_by(name: "Salud")
        subcategories = health_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Médico", "Medicamentos", "Seguro Médico"
        ])
      end
    end

    context 'education category hierarchy' do
      it 'creates education subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        education_category = user.categories.find_by(name: "Educación")
        subcategories = education_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Cursos", "Libros", "Material Escolar", "Matrículas"
        ])
      end
    end

    context 'services category hierarchy' do
      it 'creates services subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        services_category = user.categories.find_by(name: "Servicios")
        subcategories = services_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Internet", "Telefonía", "Electricidad", "Agua", "Gas"
        ])
      end
    end

    context 'income category hierarchy' do
      it 'creates income subcategories' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        income_category = user.categories.find_by(name: "Ingresos")
        subcategories = income_category.children.pluck(:name)

        expect(subcategories).to match_array([
          "Salario", "Freelance", "Inversiones", "Otros"
        ])
      end
    end

    context 'miscellaneous categories' do
      it 'creates miscellaneous categories without parent' do
        user = create(:user)
        described_class.create_categories_for_user(user)

        miscellaneous_categories = user.categories.where(parent_id: nil)
                                      .where(name: [ "Gastos Varios", "Transferencias", "Comisiones" ])
                                      .pluck(:name)

        expect(miscellaneous_categories).to match_array([
          "Gastos Varios", "Transferencias", "Comisiones"
        ])
      end
    end

    it 'is idempotent - does not create duplicate categories' do
      user = create(:user)

      # First call should create categories
      expect {
        described_class.create_categories_for_user(user)
      }.to change { user.categories.count }.by(0) # User already has categories from factory

      # Second call should not create any new categories
      expect {
        described_class.create_categories_for_user(user)
      }.not_to change { user.categories.count }

      # Verify final count
      expect(user.categories.count).to eq(43)
    end
  end
end
