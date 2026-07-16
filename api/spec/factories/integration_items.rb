# frozen_string_literal: true

FactoryBot.define do
  factory :integration_item do
    association :integration, factory: :netsuite_integration
    organization { integration&.organization || association(:organization) }
    item_type { "standard" }
    external_name { "test name" }
    external_account_code { "test_code" }
    external_id { SecureRandom.uuid }
  end
end
