# frozen_string_literal: true

FactoryBot.define do
  factory :error_detail do
    organization
    association :owner, factory: %i[invoice].sample
  end
end
