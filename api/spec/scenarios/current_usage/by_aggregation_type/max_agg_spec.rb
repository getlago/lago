# frozen_string_literal: true

require "rails_helper"

describe "Aggregation - Max Scenarios", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }
      let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
      let(:billable_metric) { create(:max_billable_metric, organization:) }

      context "with standard charge" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
        end

        it "returns the max value as usage" do
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
                properties: {item_id: "5"}
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("5.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(5000)

            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {item_id: "20"}
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("20.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(20_000)

            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: customer.external_id,
                properties: {item_id: "3"}
              }
            )

            fetch_current_usage(customer:)
            # Max stays at 20 even though last event was 3
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("20.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(20_000)
            expect(json[:customer_usage][:charges_usage].first[:events_count]).to eq(3)
          end
        end
      end

      context "with zero usage" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
        end

        it "returns zero usage when no events" do
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
