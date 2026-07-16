# frozen_string_literal: true

if Invoice.count.zero?
  Subscription.all.find_each do |subscription|
    invoice_count = (Time.current - subscription.subscription_at).fdiv(1.month).round

    (1..invoice_count).each do |offset|
      Invoices::SubscriptionService.call(
        subscriptions: [subscription],
        timestamp: subscription.subscription_at + offset.months,
        invoicing_reason: :subscription_periodic
      )
    end
  end
end
