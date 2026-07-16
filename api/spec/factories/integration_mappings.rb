# frozen_string_literal: true

FactoryBot.define do
  [
    :netsuite,
    :xero,
    :anrok,
    :avalara
  ].each do |integration_type|
    factory "#{integration_type}_mapping", class: "IntegrationMappings::#{integration_type.to_s.classify}Mapping" do
      association :integration, factory: "#{integration_type}_integration"
      association :mappable, factory: :add_on
      organization { integration&.organization || association(:organization) }
      billing_entity { nil }

      settings do
        {
          external_id: "#{integration_type}-123",
          external_account_code: "#{integration_type}-code-1",
          external_name: "Credits and Discounts"
        }
      end
    end
  end
end
