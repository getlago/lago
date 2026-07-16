# frozen_string_literal: true

FactoryBot.define do
  factory :enriched_event do
    transient do
      subscription { create(:subscription) }
      charge { create(:standard_charge, plan_id: subscription.plan_id) }
    end

    event { create(:event, organization_id: subscription.organization_id) }

    code { event.code }
    timestamp { event.timestamp }
    transaction_id { event.transaction_id }
    external_subscription_id { subscription.external_id }

    organization_id { event.organization_id }
    subscription_id { subscription.id }
    plan_id { subscription.plan_id }
    charge_id { charge.id }

    enriched_at { Time.current }
  end
end
