# frozen_string_literal: true

SubscriptionUsage = Struct.new(
  :from_datetime,
  :to_datetime,
  :issuing_date,
  :currency,
  :amount_cents,
  :total_amount_cents,
  :taxes_amount_cents,
  :fees
)
