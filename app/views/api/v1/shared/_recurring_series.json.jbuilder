# frozen_string_literal: true

json.id series.id
json.name series.name
json.description_signature series.description_signature
json.merchant_hint series.merchant_hint
json.expected_amount series.expected_amount.to_f
json.amount_variance_pct series.amount_variance_pct.to_f
json.frequency series.frequency
json.custom_interval_days series.custom_interval_days
json.interval_days series.interval_days
json.next_due_date series.next_due_date.to_s
json.last_charged_at series.last_charged_at&.to_s
json.last_notified_on series.last_notified_on&.to_s
json.category_id series.category_id
json.transaction_type series.transaction_type
json.status series.status
json.source series.source
json.confidence_score series.confidence_score
json.occurrences_count series.occurrences_count
json.notes series.notes
json.monthly_estimate series.monthly_estimate.to_f
json.annual_estimate series.annual_estimate.to_f
json.detected_at series.detected_at&.iso8601
json.confirmed_at series.confirmed_at&.iso8601
json.cancelled_at series.cancelled_at&.iso8601
json.created_at series.created_at.iso8601
json.updated_at series.updated_at.iso8601
