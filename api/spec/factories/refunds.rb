# frozen_string_literal: true

FactoryBot.define do
  factory :refund do
    credit_note
    refundable { credit_note }
    payment
    organization { credit_note&.organization || payment&.organization || association(:organization) }
    association :payment_provider, factory: :stripe_provider
    association :payment_provider_customer, factory: :stripe_customer

    amount_cents { 200 }
    amount_currency { "EUR" }
    provider_refund_id { SecureRandom.uuid }
    reason { :credit_note }
    status { "pending" }

    trait :subscription_activation_expired do
      credit_note { nil }
      association :refundable, factory: :invoice, status: :closed
      reason { :subscription_activation_expired }
      organization { refundable.organization }
      payment do
        association(
          :payment,
          payable: refundable,
          organization: refundable.organization,
          customer: refundable.customer,
          payable_payment_status: "succeeded"
        )
      end
      payment_provider { payment.payment_provider }
      payment_provider_customer { payment.payment_provider_customer }
      amount_cents { payment.amount_cents }
      amount_currency { payment.amount_currency }
    end

    factory :subscription_activation_expired_refund do
      subscription_activation_expired
    end
  end
end
