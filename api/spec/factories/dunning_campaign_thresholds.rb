# frozen_string_literal: true

FactoryBot.define do
  factory :dunning_campaign_threshold do
    dunning_campaign
    organization { dunning_campaign&.organization || association(:organization) }

    currency { "USD" }
    amount_cents { 1000 }
  end
end
