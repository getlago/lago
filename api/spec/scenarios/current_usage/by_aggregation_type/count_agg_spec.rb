# frozen_string_literal: true

require "rails_helper"

describe "Aggregation - Count Scenarios", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }
      let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
      let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

      context "with standard charge" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "5"})
        end

        it "returns the expected current usage" do
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
            3.times do
              create_event(
                {
                  code: billable_metric.code,
                  transaction_id: SecureRandom.uuid,
                  external_subscription_id: customer.external_id
                }
              )
            end

            fetch_current_usage(customer:)

            customer_usage = json[:customer_usage]
            expect(customer_usage[:total_amount_cents]).to eq(1500)
            expect(customer_usage[:charges_usage].count).to eq(1)

            charge_usage = customer_usage[:charges_usage].first
            expect(charge_usage[:units]).to eq("3.0")
            expect(charge_usage[:events_count]).to eq(3)
            expect(charge_usage[:amount_cents]).to eq(1500)
          end
        end
      end

      context "with incremental events" do
        before do
          create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
        end

        it "accumulates usage across events" do
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
                external_subscription_id: customer.external_id
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("1.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(1000)

            2.times do
              create_event(
                {
                  code: billable_metric.code,
                  transaction_id: SecureRandom.uuid,
                  external_subscription_id: customer.external_id
                }
              )
            end

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("3.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(3000)
          end
        end
      end
    end
  end
end
