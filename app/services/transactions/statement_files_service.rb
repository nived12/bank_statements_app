# frozen_string_literal: true

##
# Transactions::StatementFilesService
# Service for handling statement files API requests
#
class Transactions::StatementFilesService < ApplicationService
  def initialize(user, bank_account_id: nil)
    super()
    @user = user
    @bank_account_id = bank_account_id
  end

  def call
    load_statement_files
    success(build_response)
  end

  private

  attr_reader :user, :bank_account_id, :statement_files

  def load_statement_files
    @statement_files = if bank_account_id.present?
      user.statement_files
          .joins(:bank_account)
          .where(bank_account_id: bank_account_id)
          .by_cutoff_date
    else
      user.statement_files
          .joins(:bank_account)
          .by_cutoff_date
    end
  end

  def build_response
    {
      statement_files: statement_files.map do |sf|
        {
          id: sf.id,
          safe_filename: sf.safe_filename,
          bank_account_display_name: sf.bank_account.display_name
        }
      end
    }
  end
end
