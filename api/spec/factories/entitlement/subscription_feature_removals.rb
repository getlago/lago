# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_feature_removal, class: "Entitlement::SubscriptionFeatureRemoval" do
    organization { feature&.organization || privilege&.organization || association(:organization) }
    subscription { association(:subscription, organization:) }

    entitlement_feature_id { nil }
    entitlement_privilege_id { nil }
  end
end
