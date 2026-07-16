# frozen_string_literal: true

require "rails_helper"

describe "Aggregation - Latest Scenarios", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }
      let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
      let(:billable_metric) { create(:latest_billable_metric, organization:) }

      context "with standard charge" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "5"})
        end

        it "returns the latest value as usage" do
          travel_to(DateTime.new(2024, 3, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          travel_to(DateTime.new(2024, 3, 5, 1)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {item_id: "10"}
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("10.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(5000)
          end

          travel_to(DateTime.new(2024, 3, 5, 2)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {item_id: "3"}
              }
            )

            fetch_current_usage(customer:)
            # Latest replaces previous value
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("3.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(1500)
          end

          travel_to(DateTime.new(2024, 3, 5, 3)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {item_id: "50"}
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("50.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(25_000)
            expect(json[:customer_usage][:charges_usage].first[:events_count]).to eq(3)
          end
        end
      end

      context "with zero usage" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "5"})
        end

        it "returns zero usage when no events" do
          travel_to(DateTime.new(2024, 3, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          travel_to(DateTime.new(2024, 3, 5)) do
            fetch_current_usage(customer:)

            charge_usage = json[:customer_usage][:charges_usage].first
            expect(charge_usage[:units]).to eq("0.0")
            expect(charge_usage[:events_count]).to eq(0)
            expect(charge_usage[:amount_cents]).to eq(0)
          end
        end
      end
    end
  end
end
