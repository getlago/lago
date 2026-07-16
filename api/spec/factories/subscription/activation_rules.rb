# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_activation_rule, class: "Subscription::ActivationRule::Payment", aliases: [:payment_subscription_activation_rule] do
    subscription
    organization { subscription&.organization || association(:organization) }
    type { "payment" }
    status { "inactive" }
    timeout_hours { 48 }
  end
end
