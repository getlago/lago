# frozen_string_literal: true

FactoryBot.define do
  factory :charge_filter_value do
    transient do
      billable_metric_filter { create(:billable_metric_filter) }
    end

    charge_filter
    organization { charge_filter&.organization || association(:organization) }
    billable_metric_filter_id { billable_metric_filter.id }
    values { [billable_metric_filter.values.sample] }
  end
end
