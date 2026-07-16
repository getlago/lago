# frozen_string_literal: true

require "rails_helper"

# Regression test for ISSUE-1799: ClickHouse query fails with empty Tuple()
# when ignored_filters contains empty hashes or hashes with all-empty-array
# values. These states should not occur — charge filters should always have
# values and duplicates should not exist — but missing validations allow them
# in production. The store-level defensive guards prevent invalid SQL.
describe "Current Usage - Filters with empty ignored_filters entries", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }
      let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
      let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "value") }

      # Filters with no ChargeFilterValue records should not exist but can due
      # to missing validations. They produce {} in ignored_filters.
      context "when charge filters have no values" do
        before do
          cloud_filter = create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp])

          charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})

          create(:charge_filter, charge:, properties: {amount: "5"}, invoice_display_name: "Empty A")
          create(:charge_filter, charge:, properties: {amount: "8"}, invoice_display_name: "Empty B")
          create(:charge_filter, charge:, properties: {amount: "3"}, invoice_display_name: "AWS")
            .tap { |cf| create(:charge_filter_value, charge_filter: cf, billable_metric_filter: cloud_filter, values: ["aws"]) }
        end

        it "returns current usage without SQL errors" do
          travel_to(DateTime.new(2024, 3, 5)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          travel_to(DateTime.new(2024, 3, 6)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {cloud: "aws", value: 10}
              }
            )

            fetch_current_usage(customer:)

            expect(json[:customer_usage][:charges_usage].first[:filters].count).to eq(4)
          end
        end
      end

      # Duplicate filters with identical values should not exist but can due
      # to missing validations. The child's subtraction zeroes out all arrays,
      # producing {"cloud" => []} in ignored_filters.
      context "when a child filter's values are a subset of the parent's" do
        before do
          cloud_filter = create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp])

          charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})

          create(:charge_filter, charge:, properties: {amount: "5"}, invoice_display_name: "All clouds")
            .tap { |cf| create(:charge_filter_value, charge_filter: cf, billable_metric_filter: cloud_filter, values: %w[aws gcp]) }
          create(:charge_filter, charge:, properties: {amount: "3"}, invoice_display_name: "AWS only")
            .tap { |cf| create(:charge_filter_value, charge_filter: cf, billable_metric_filter: cloud_filter, values: ["aws"]) }
        end

        it "returns current usage without SQL errors" do
          travel_to(DateTime.new(2024, 3, 5)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          travel_to(DateTime.new(2024, 3, 6)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {cloud: "aws", value: 10}
              }
            )

            fetch_current_usage(customer:)

            expect(json[:customer_usage][:charges_usage].first[:filters].count).to eq(3)
          end
        end
      end
    end
  end
end
