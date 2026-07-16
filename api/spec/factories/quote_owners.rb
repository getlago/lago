# frozen_string_literal: true

FactoryBot.define do
  factory :quote_owner do
    quote
    organization { quote.organization }
    user { create(:membership, organization: quote.organization).user }
  end
end
