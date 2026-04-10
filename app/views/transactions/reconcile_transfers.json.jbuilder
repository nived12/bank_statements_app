json.success @success

if @success
  json.auto_linked @auto_linked
  json.candidates_created @candidates_created

  parts = []
  parts << t("transactions.reconcile_linked", count: @auto_linked) if @auto_linked > 0
  parts << t("transactions.reconcile_candidates", count: @candidates_created) if @candidates_created > 0
  json.message parts.any? ? parts.join(" · ") : t("transactions.reconcile_no_matches")
else
  json.error @error
end
