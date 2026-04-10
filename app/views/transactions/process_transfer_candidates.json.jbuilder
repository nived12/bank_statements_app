json.success @success

if @success
  json.message t("transactions.transfer_candidates.process_success")
  json.linked_count @linked_count
  json.rejected_count @rejected_count
else
  json.error @error
end
