# frozen_string_literal: true

FactoryBot.define do
  factory :common_event, class: "Events::Common" do
    transient do
      organization { create(:organization) }
      billable_metric { create(:billable_metric, organization: organization) }
      subscription { create(:subscription, organization: organization) }
    end

    organization_id { organization.id }
    transaction_id { SecureRandom.uuid }
    external_subscription_id { subscription.external_id }
    timestamp { Time.current }
    code { billable_metric.code }
    properties { {} }
  end
end
