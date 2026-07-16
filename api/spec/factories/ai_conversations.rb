# frozen_string_literal: true

FactoryBot.define do
  factory :ai_conversation do
    organization
    membership
    name { "How can I create a coupon?" }
    mistral_conversation_id { "mistral-conv-id-123" }
  end
end
