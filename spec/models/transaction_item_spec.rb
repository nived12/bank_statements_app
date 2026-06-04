# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionItem, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account) }

  let(:valid_attrs) { { transaction_record: transaction, name: "Galletas", amount: 25.0, position: 0 } }

  describe "validations" do
    it "is valid with required fields" do
      expect(described_class.new(valid_attrs)).to be_valid
    end

    it "requires name" do
      expect(described_class.new(valid_attrs.merge(name: ""))).not_to be_valid
    end

    it "enforces name length 1..120" do
      expect(described_class.new(valid_attrs.merge(name: "a" * 121))).not_to be_valid
      expect(described_class.new(valid_attrs.merge(name: "a"))).to be_valid
    end

    it "requires amount >= 0" do
      expect(described_class.new(valid_attrs.merge(amount: -1))).not_to be_valid
      expect(described_class.new(valid_attrs.merge(amount: 0))).to be_valid
    end

    it "requires position >= 0" do
      expect(described_class.new(valid_attrs.merge(position: -1))).not_to be_valid
    end

    it "requires integer position" do
      expect(described_class.new(valid_attrs.merge(position: 1.5))).not_to be_valid
    end

    it "belongs to a transaction" do
      expect(described_class.new(valid_attrs.merge(transaction_record: nil))).not_to be_valid
    end
  end

  describe "default_scope ordering" do
    let!(:item_b) { create(:transaction_item, transaction_record: transaction, name: "B", position: 2) }
    let!(:item_a) { create(:transaction_item, transaction_record: transaction, name: "A", position: 0) }
    let!(:item_c) { create(:transaction_item, transaction_record: transaction, name: "C", position: 1) }

    it "returns items ordered by position then id" do
      names = transaction.transaction_items.map(&:name)
      expect(names).to eq(%w[A C B])
    end
  end
end
