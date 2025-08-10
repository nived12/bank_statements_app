class Transactions::Importer
  class << self
    def call(statement_file, json: nil)
      json ||= statement_file.parsed_json
      return 0 unless json.is_a?(Hash) && json["transactions"].is_a?(Array)

      user = statement_file.user
      bank_account = statement_file.bank_account
      created = 0

      json["transactions"].each do |t|
        cat = resolve_category(user, t["category"], t["sub_category"])

        Transaction.create!(
          user: user,
          bank_account: bank_account,
          statement_file: statement_file,
          date: Date.parse(t["date"].to_s),
          description: t["description"].to_s,
          amount: to_decimal(t["amount"]),
          transaction_type: normalize_tx_type(t["transaction_type"], t["amount"]),
          bank_entry_type: normalize_bank_type(t["bank_entry_type"]),
          category: cat,
          merchant: t["merchant"],
          reference: t["reference"]
        )
        created += 1
      end

      created
    end

    private

    def resolve_category(user, category_name, subcategory_name)
      return nil if category_name.to_s.strip.empty?

      parent = Category.find_or_create_by!(user: user, parent_id: nil, name: category_name.strip)
      return parent if subcategory_name.to_s.strip.empty?

      Category.find_or_create_by!(user: user, parent: parent, name: subcategory_name.strip)
    end

    def to_decimal(v)
      return v.to_d if v.is_a?(Numeric)
      v.to_s.tr(",", "").to_d
    end

    def normalize_tx_type(v, amount)
      x = v.to_s.downcase.strip
      return x if %w[income fixed_expense variable_expense].include?(x)
      amt = to_decimal(amount).to_f
      amt < 0 ? "variable_expense" : "income"
    end

    def normalize_bank_type(v)
      x = v.to_s.downcase.strip
      return "credit" if %w[credit cr].include?(x)
      return "debit"  if %w[debit dr].include?(x)
      nil
    end
  end
end
