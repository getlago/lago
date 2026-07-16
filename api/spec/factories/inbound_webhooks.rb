# frozen_string_literal: true

FactoryBot.define do
  factory :inbound_webhook do
    organization

    source { "stripe" }
    event_type { "payment_intent.succeeded" }
    status { "pending" }
    code { "webhook-endpoint-code" }
    signature { "MySignature" }

    payload { "{}" }
  end
end
