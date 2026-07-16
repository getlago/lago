# frozen_string_literal: true

FactoryBot.define do
  factory :recurring_transaction_rule do
    wallet
    organization { wallet&.organization || association(:organization) }
    paid_credits { "10.00" }
    granted_credits { "10.00" }
    interval { "monthly" }
    trigger { "interval" }
    transaction_name { "Recurring Transaction Rule" }

    after(:build) do |rule|
      rule.grants_target_top_up = false if rule.method.to_s == "target" && rule.grants_target_top_up.nil?
    end
  end
end
