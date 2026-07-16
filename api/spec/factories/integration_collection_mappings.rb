# frozen_string_literal: true

FactoryBot.define do
  factory :netsuite_collection_mapping, class: "IntegrationCollectionMappings::NetsuiteCollectionMapping" do
    association :integration, factory: :netsuite_integration
    mapping_type { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit].sample }
    organization { integration&.organization || association(:organization) }
    billing_entity { nil }

    settings do
      {
        external_id: "netsuite-123",
        external_account_code: "netsuite-code-1",
        external_name: "Credits and Discounts",
        tax_nexus: "tax-nexus-1",
        tax_type: "tax-type-1",
        tax_code: "tax-code-1"
      }
    end
  end

  factory :netsuite_currencies_mapping, class: "IntegrationCollectionMappings::NetsuiteCollectionMapping" do
    association :integration, factory: :netsuite_integration
    organization { integration&.organization || association(:organization) }

    mapping_type { :currencies }
    settings do
      {
        currencies: {
          "EUR" => "3",
          "USD" => "7"
        }
      }
    end
  end

  factory :xero_collection_mapping, class: "IntegrationCollectionMappings::XeroCollectionMapping" do
    association :integration, factory: :xero_integration
    mapping_type { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit account].sample }
    organization { integration&.organization || association(:organization) }
    billing_entity { nil }

    settings do
      {
        external_id: "xero-123",
        external_account_code: "xero-code-1",
        external_name: "Credits and Discounts"
      }
    end
  end

  factory :anrok_collection_mapping, class: "IntegrationCollectionMappings::AnrokCollectionMapping" do
    association :integration, factory: :anrok_integration
    mapping_type { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit account].sample }
    organization { integration&.organization || association(:organization) }
    billing_entity { nil }

    settings do
      {
        external_id: "anrok-123",
        external_account_code: "anrok-code-1",
        external_name: "Credits and Discounts"
      }
    end
  end

  factory :avalara_collection_mapping, class: "IntegrationCollectionMappings::AvalaraCollectionMapping" do
    association :integration, factory: :avalara_integration
    mapping_type { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit account].sample }
    organization { integration&.organization || association(:organization) }
    billing_entity { nil }

    settings do
      {
        external_id: "avalara-123",
        external_account_code: "avalara-code-1",
        external_name: "Credits and Discounts"
      }
    end
  end
end
