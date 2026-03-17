# frozen_string_literal: true

require "csv"

##
# Transactions::Exporter
# Generates CSV data from a filtered transactions relation
#
class Transactions::Exporter < ApplicationService
  def initialize(transactions)
    super()
    @transactions = transactions
  end

  def call
    csv_data = generate_csv
    success(csv_data)
  rescue => e
    errors.add(:base, :export_failed, message: "Failed to export transactions: #{e.message}")
    failure
  end

  private

  attr_reader :transactions

  def generate_csv
    CSV.generate do |csv|
      csv << headers
      transactions.find_each { |t| csv << row(t) }
    end
  end

  def headers
    [
      I18n.t("table_headers.date"),
      I18n.t("transactions.bank_name"),
      I18n.t("table_headers.account"),
      I18n.t("table_headers.description"),
      I18n.t("transactions.merchant"),
      I18n.t("transactions.reference"),
      I18n.t("table_headers.amount"),
      I18n.t("table_headers.transaction_type"),
      I18n.t("transactions.category"),
      I18n.t("transactions.parent_category")
    ]
  end

  def row(transaction)
    [
      transaction.date&.strftime("%Y-%m-%d"),
      transaction.bank_account&.bank&.name,
      transaction.bank_account&.custom_name,
      transaction.description,
      transaction.merchant,
      transaction.reference,
      transaction.amount.to_f,
      I18n.t("transaction_types.#{transaction.transaction_type}"),
      transaction.category&.name,
      transaction.category&.parent&.name
    ]
  end
end
