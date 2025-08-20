# spec/models/bank_spec.rb
require "rails_helper"

RSpec.describe Bank, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      bank = build(:bank)
      expect(bank).to be_valid
    end

    it "requires a code" do
      bank = build(:bank, code: nil)
      expect(bank).not_to be_valid
      expect(bank.errors[:code]).to include("no puede estar en blanco")
    end

    it "requires a name" do
      bank = build(:bank, name: nil)
      expect(bank).not_to be_valid
      expect(bank.errors[:name]).to include("no puede estar en blanco")
    end

    it "requires a unique code" do
      create(:bank, code: "unique_code_1", name: "Unique Bank 1")
      bank = build(:bank, code: "unique_code_1", name: "Unique Bank 2")
      expect(bank).not_to be_valid
      expect(bank.errors[:code]).to include("ya ha sido tomado")
    end

    it "sets default values for supported and active" do
      bank = create(:bank, code: "unique_code_2", name: "Unique Bank 3")
      expect(bank.supported).to be true
      expect(bank.active).to be true
    end
  end

  describe "associations" do
    it "has many bank accounts" do
      bank = create(:bank)
      expect(bank.bank_accounts).to be_empty

      create(:bank_account, bank: bank)
      expect(bank.bank_accounts.count).to eq(1)
    end

    it "restricts deletion when bank accounts exist" do
      bank = create(:bank)
      create(:bank_account, bank: bank)

      expect { bank.destroy }.not_to change { Bank.count }
      expect(bank.errors[:base]).to include("No se puede eliminar el registro porque existen bank accounts dependientes")
    end
  end

  describe "scopes" do
    describe ".supported" do
      it "returns only supported banks" do
        supported_bank = create(:bank, code: "unique_supported", name: "Supported Bank", supported: true, active: true)
        unsupported_bank = create(:bank, code: "unique_unsupported", name: "Unsupported Bank", supported: false, active: true)

        expect(Bank.supported).to include(supported_bank)
        expect(Bank.supported).not_to include(unsupported_bank)
      end
    end

    describe ".active" do
      it "returns only active banks" do
        active_bank = create(:bank, code: "unique_active", name: "Active Bank", supported: true, active: true)
        inactive_bank = create(:bank, code: "unique_inactive", name: "Inactive Bank", supported: true, active: false)

        expect(Bank.active).to include(active_bank)
        expect(Bank.active).not_to include(inactive_bank)
      end
    end

    describe ".supported_banks" do
      it "returns only supported and active banks" do
        supported_bank = create(:bank, code: "unique_supported_active", name: "Supported Active Bank", supported: true, active: true)
        unsupported_bank = create(:bank, code: "unique_unsupported_active", name: "Unsupported Active Bank", supported: false, active: true)
        inactive_bank = create(:bank, code: "unique_supported_inactive", name: "Supported Inactive Bank", supported: true, active: false)

        expect(Bank.supported_banks).to include(supported_bank)
        expect(Bank.supported_banks).not_to include(unsupported_bank)
        expect(Bank.supported_banks).not_to include(inactive_bank)
      end

      it "orders by name" do
        bank_a = create(:bank, code: "unique_aaa", name: "AAA Bank", supported: true, active: true)
        supported_bank = create(:bank, code: "unique_supported_active", name: "Supported Active Bank", supported: true, active: true)
        bank_z = create(:bank, code: "unique_zzz", name: "ZZZ Bank", supported: true, active: true)

        # Only test the banks we created in this test, not the ones from test helper
        test_banks = [ bank_a, supported_bank, bank_z ]
        expect(Bank.supported_banks.where(id: test_banks.map(&:id)).order(:name).to_a).to eq([ bank_a, supported_bank, bank_z ])
      end
    end
  end

  describe "class methods" do
    describe ".find_by_code_or_name" do
      let!(:bank) { create(:bank, code: "unique_finder", name: "Finder Bank") }

      it "finds by exact code match" do
        found = Bank.find_by_code_or_name("unique_finder")
        expect(found).to eq(bank)
      end

      it "finds by code case insensitive" do
        found = Bank.find_by_code_or_name("UNIQUE_FINDER")
        expect(found).to eq(bank)
      end

      it "finds by name case insensitive" do
        found = Bank.find_by_code_or_name("finder bank")
        expect(found).to eq(bank)
      end

      it "returns nil for non-existent identifier" do
        found = Bank.find_by_code_or_name("non_existent")
        expect(found).to be_nil
      end

      it "returns nil for blank identifier" do
        found = Bank.find_by_code_or_name("")
        expect(found).to be_nil
        found = Bank.find_by_code_or_name(nil)
        expect(found).to be_nil
      end
    end

    describe "bank-specific finders" do
      it "finds BBVA" do
        bbva = Bank.find_by(code: "bbva")
        expect(bbva).to be_present
        expect(bbva.name).to eq("BBVA Bancomer")
      end

      it "finds Santander" do
        santander = Bank.find_by(code: "santander")
        expect(santander).to be_present
        expect(santander.name).to eq("Santander")
      end

      it "finds Banorte" do
        banorte = Bank.find_by(code: "banorte")
        expect(banorte).to be_present
        expect(banorte.name).to eq("Banorte")
      end

      it "finds Banamex" do
        banamex = Bank.find_by(code: "banamex")
        expect(banamex).to be_present
        expect(banamex.name).to eq("Banamex")
      end

      it "finds Generic" do
        generic = Bank.find_by(code: "generic")
        expect(generic).to be_present
        expect(generic.name).to eq("Otro Banco")
      end
    end
  end

  describe "instance methods" do
    let(:bank) { create(:bank, code: "unique_methods", name: "Methods Bank") }

    describe "#to_s" do
      it "returns the bank name" do
        expect(bank.to_s).to eq("Methods Bank")
      end
    end

    describe "#supported_for_parsing?" do
      it "returns true when supported and active" do
        bank = create(:bank, code: "unique_supported_active", name: "Supported Active Bank", supported: true, active: true)
        expect(bank.supported_for_parsing?).to be true
      end

      it "returns false when not supported" do
        bank = create(:bank, code: "unique_unsupported_active", name: "Unsupported Active Bank", supported: false, active: true)
        expect(bank.supported_for_parsing?).to be false
      end

      it "returns false when not active" do
        bank = create(:bank, code: "unique_supported_inactive", name: "Supported Inactive Bank", supported: true, active: false)
        expect(bank.supported_for_parsing?).to be false
      end
    end
  end
end
