# frozen_string_literal: true

FactoryBot.define do
  factory :wallet do
    customer
    organization { customer&.organization || association(:organization) }
    name { Faker::Name.name }
    code { name.to_s.parameterize(separator: "_").presence || "default" }
    status { "active" }
    rate_amount { "1.00" }
    currency { "EUR" }
    credits_balance { 0 }
    balance_cents { 0 }
    consumed_credits { 0 }
    invoice_requires_successful_payment { false }
    traceable { true }

    trait :terminated do
      status { "terminated" }
    end

    trait :with_recurring_transaction_rules do
      recurring_transaction_rules { [association(:recurring_transaction_rule)] }
    end

    trait :with_top_up_limits do
      paid_top_up_min_amount_cents { rand(100..1000) }
      paid_top_up_max_amount_cents { rand(2000..5000) }
    end

    trait :with_inbound_transaction do
      after(:create) do |wallet|
        create(:wallet_transaction,
          wallet:,
          organization: wallet.organization,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: wallet.credits_balance,
          credit_amount: wallet.credits_balance,
          remaining_amount_cents: wallet.balance_cents)
      end
    end
  end
end
