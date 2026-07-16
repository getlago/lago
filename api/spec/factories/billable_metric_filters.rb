# frozen_string_literal: true

FactoryBot.define do
  factory :billable_metric_filter do
    billable_metric
    organization { billable_metric&.organization || association(:organization) }
    key { Faker::Name.name.underscore }
    values { [Faker::Name.name, Faker::Name.name, Faker::Name.name] }
  end
end
