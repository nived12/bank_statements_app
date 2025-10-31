json.extract! transaction, :id, :date, :description, :amount, :transaction_type, :merchant, :reference, :source, :linked_transfer_id

if transaction.bank_account
  json.bank_account do
    json.id transaction.bank_account.id
    json.name transaction.bank_account.display_name rescue transaction.bank_account.custom_name rescue ""
    json.account_number transaction.bank_account.account_number rescue ""
  end
else
  json.bank_account nil
end

if transaction.category
  json.category do
    json.id transaction.category.id
    json.name transaction.category.name
    json.parent_id transaction.category.parent_id
    if transaction.category.parent
      json.parent do
        json.id transaction.category.parent.id
        json.name transaction.category.parent.name
      end
    else
      json.parent nil
    end
  end
else
  json.category nil
end

if transaction.statement_file
  json.statement_file do
    json.id transaction.statement_file.id
    json.filename transaction.statement_file.safe_filename
  end
else
  json.statement_file nil
end

# Transfer account information
if transaction.transfer? && transaction.linked_transfer_id.present?
  begin
    # Load linked_transfer - use reload if needed to ensure association is loaded
    linked_transfer = transaction.linked_transfer
    
    if linked_transfer
      # Get bank_account_id directly from the linked transfer
      bank_account_id = linked_transfer.bank_account_id || linked_transfer.read_attribute(:bank_account_id)
      
      if bank_account_id
        # Try to access bank_account - use association if loaded, otherwise fetch
        bank_account = nil
        begin
          # Check if association is loaded
          if linked_transfer.association(:bank_account).loaded?
            bank_account = linked_transfer.bank_account
          else
            # Association not loaded, fetch directly
            bank_account = BankAccount.find_by(id: bank_account_id)
          end
        rescue => e
          # If association access fails, fetch directly
          bank_account = BankAccount.find_by(id: bank_account_id)
        end
        
        if bank_account
          json.transfer_account_id bank_account_id
          json.transfer_account do
            json.id bank_account.id
            json.name bank_account.display_name rescue ""
            json.account_number bank_account.account_number rescue ""
          end
        else
          json.transfer_account_id nil
          json.transfer_account nil
        end
      else
        json.transfer_account_id nil
        json.transfer_account nil
      end
    else
      json.transfer_account_id nil
      json.transfer_account nil
    end
  rescue => e
    # Silently fail - transfer account is optional
    Rails.logger.debug "Could not load transfer account for transaction #{transaction.id}: #{e.message}" if Rails.logger
    json.transfer_account_id nil
    json.transfer_account nil
  end
else
  json.transfer_account_id nil
  json.transfer_account nil
end
