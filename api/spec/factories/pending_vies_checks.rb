# frozen_string_literal: true

FactoryBot.define do
  factory :pending_vies_check do
    organization {
      customer&.organization || billing_entity&.organization || association(:organization)
    }
    billing_entity { customer&.billing_entity || association(:billing_entity) }
    customer
    attempts_count { 1 }
    last_attempt_at { Time.current }
    last_error_type { "timeout" }
    tax_identification_number { customer&.tax_identification_number || "EU123456789" }

    trait :with_multiple_attempts do
      attempts_count { 3 }
      last_error_message { "Service temporarily unavailable" }
      last_error_type { "service_unavailable" }
    end
  end
end
