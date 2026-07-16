# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_endpoint do
    organization
    webhook_url { Faker::Internet.url }
  end
end
