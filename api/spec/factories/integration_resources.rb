# frozen_string_literal: true

FactoryBot.define do
  factory :integration_resource do
    association :syncable, factory: %i[invoice payment credit_note].sample
    association :integration, factory: :netsuite_integration
    organization { integration&.organization || association(:organization) }
    external_id { SecureRandom.uuid }
  end
end
