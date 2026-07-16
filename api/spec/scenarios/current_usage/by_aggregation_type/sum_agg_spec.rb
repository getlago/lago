# frozen_string_literal: true

require "rails_helper"

describe "Aggregation - Sum Scenarios", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }

      let(:plan) { create(:plan, organization:, amount_cents: 0) }
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:) }

      before { charge }

      context "with in advance charge and groups" do
        let(:charge) do
          create(
            :standard_charge,
            billable_metric:,
            plan:,
            prorated: true,
            pay_in_advance: true,
            properties: {
              amount: "29",
              grouped_by: %w[key_1 key_2 key_3]
            }
          )
        end

        it "creates fees for each events" do
          travel_to(DateTime.new(2024, 2, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          subscription = customer.subscriptions.first

          travel_to(DateTime.new(2024, 2, 6, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => 10,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(1)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("10.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => -5,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(2)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("5.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 3)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => 2,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(3)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("7.0")
          end
        end
      end

      context "with multiple subscriptions attached to the same plan" do
        let(:charge) do
          create(
            :standard_charge,
            billable_metric:,
            plan:,
            prorated: true,
            pay_in_advance: true,
            properties: {
              amount: "29",
              grouped_by: %w[key_1 key_2 key_3]
            }
          )
        end

        it "creates fees for each events" do
          travel_to(DateTime.new(2024, 2, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: "#{customer.external_id}_1",
                plan_code: plan.code
              }
            )
          end

          subscription1 = customer.subscriptions.first

          travel_to(DateTime.new(2024, 2, 1, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: "#{customer.external_id}_2",
                plan_code: plan.code
              }
            )
          end

          subscription2 = customer.subscriptions.order(:created_at).last

          travel_to(DateTime.new(2024, 2, 6, 0, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription1.external_id,
                properties: {
                  "item_id" => 10,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(1)

            fetch_current_usage(customer:, subscription: subscription1)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("10.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 0, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription1.external_id,
                properties: {
                  "item_id" => -5,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(2)

            fetch_current_usage(customer:, subscription: subscription1)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("5.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 0, 3)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription1.external_id,
                properties: {
                  "item_id" => 2,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            expect(Fee.count).to eq(3)

            fetch_current_usage(customer:, subscription: subscription1)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("7.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 1, 0, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription2.external_id,
                properties: {
                  "item_id" => 10,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            fetch_current_usage(customer:, subscription: subscription2)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("10.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 1, 0, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription2.external_id,
                properties: {
                  "item_id" => -5,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            fetch_current_usage(customer:, subscription: subscription2)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("5.0")
          end

          travel_to(DateTime.new(2024, 2, 6, 1, 0, 3)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription2.external_id,
                properties: {
                  "item_id" => 2,
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                }
              }
            )

            fetch_current_usage(customer:, subscription: subscription2)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24_000)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("7.0")
          end
        end
      end
    end
  end
end
