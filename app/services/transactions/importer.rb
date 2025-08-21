class Transactions::Importer
  class << self
    def call(statement_file, json: nil)
      json ||= statement_file.parsed_json
      return 0 unless json.is_a?(Hash) && json["transactions"].is_a?(Array)

      user = statement_file.user
      bank_account = statement_file.bank_account
      created = 0

      json["transactions"].each do |t|
        # Handle both new format (category_id) and old format (category names)
        if t["category_id"].present?
          # New format: use category_id directly
          category_id = t["category_id"]
          sub_category_id = t["sub_category_id"]
        elsif t["category"].present?
          # Old format: resolve category names to IDs
          cat = resolve_category(user, t["category"], t["sub_category"])
          category_id = cat&.id
          sub_category_id = nil
        else
          # No category information
          category_id = nil
          sub_category_id = nil
        end

        Transaction.create!(
          user: user,
          bank_account: bank_account,
          statement_file: statement_file,
          date: Date.parse(t["date"].to_s),
          description: t["description"].to_s,
          amount: to_decimal(t["amount"]),
          transaction_type: normalize_tx_type(t["transaction_type"], t["amount"]),
          bank_entry_type: normalize_bank_type(t["bank_entry_type"]),
          category_id: category_id,
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

      # Try to find existing categories instead of creating new ones
      parent = user.categories.find_by(parent_id: nil, name: category_name.strip)
      return parent if subcategory_name.to_s.strip.empty?

      child = user.categories.find_by(parent: parent, name: subcategory_name.strip)

      # If no category found, return the "Sin Categorizar" category
      return user.categories.find_by(name: "Sin Categorizar") unless parent || child

      child || parent
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
