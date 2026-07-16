# frozen_string_literal: true

require "rails_helper"

describe "Aggregation - Unique Count Scenarios", transaction: false do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization:) }

      let(:plan) { create(:plan, organization:, amount_cents: 0) }
      let(:billable_metric) { create(:unique_count_billable_metric, :recurring, organization:) }
      let(:charge) do
        create(:standard_charge, plan:, billable_metric:, properties: {amount: "1", grouped_by: %w[key_1 key_2 key_3]})
      end

      before { charge }

      it "creates fees and keeps the units between periods" do
        travel_to(DateTime.new(2024, 2, 6)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        subscription = customer.subscriptions.first

        travel_to(DateTime.new(2024, 2, 7)) do
          create_event({
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            properties: {
              "item_id" => "001",
              "key_1" => "2024",
              "key_2" => "Feb",
              "key_3" => "08"
            },
            timestamp: Time.zone.parse("2024-02-07 00:00:00.000").to_f
          })

          create_event({
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            properties: {
              "item_id" => "001",
              "key_1" => "2024",
              "key_2" => "Feb",
              "key_3" => "06"
            },
            timestamp: Time.zone.parse("2024-02-07 00:00:02.000").to_f
          })

          create_event({
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            properties: {
              "item_id" => "002",
              "key_1" => "2024",
              "key_2" => "Feb",
              "key_3" => "06"
            },
            timestamp: Time.zone.parse("2024-02-07 00:00:03.000").to_f
          })

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(300)
        end
      end

      context "with in advance charge and group by" do
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

          travel_to(DateTime.new(2024, 2, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => "001",
                  "operation_type" => "remove",
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                },
                timestamp: Time.zone.parse("2024-02-01T01:00:00").to_f
              }
            )

            expect(Fee.count).to eq(1)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(0)

            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => "001",
                  "operation_type" => "add",
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                },
                timestamp: Time.zone.parse("2024-02-01T01:00:10").to_f
              }
            )

            expect(Fee.count).to eq(2)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(2900)
          end

          travel_to(DateTime.new(2024, 2, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => "001",
                  "operation_type" => "add",
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                },
                timestamp: Time.zone.parse("2024-02-02T01:00:00").to_f
              }
            )

            expect(Fee.count).to eq(3)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(2900)
          end

          travel_to(DateTime.new(2024, 2, 3)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {
                  "item_id" => "001",
                  "operation_type" => "remove",
                  "key_1" => "2024",
                  "key_2" => "Feb",
                  "key_3" => "06"
                },
                timestamp: Time.zone.parse("2024-02-03T01:00:00").to_f
              }
            )

            expect(Fee.count).to eq(4)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(2900)
          end
        end
      end

      context "with prorated in advance charge" do
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric:,
            prorated: true,
            pay_in_advance: true,
            properties: {amount: "1"}
          )
        end

        it "returns the expected result" do
          travel_to(DateTime.new(2024, 2, 23, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar"
              }
            )
          end

          subscription = customer.subscriptions.first

          travel_to(DateTime.new(2024, 2, 23, 1, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_1"},
                timestamp: Time.zone.parse("2024-02-23T01:02:00").to_f
              }
            )

            expect(Fee.count).to eq(1)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("1.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(24) # (7 / 29) * 1
          end

          travel_to(DateTime.new(2024, 2, 29, 1, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_1", "operation_type" => "remove"},
                timestamp: Time.zone.parse("2024-02-29T01:01:00").to_f
              }
            )

            expect(Fee.count).to eq(2)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("0.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(24) # (7 / 29) * 1
          end

          travel_to(DateTime.new(2024, 2, 29, 1, 2)) do
            # NOTE: Remove once again the seat, it should not impact the current usage
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_1", "operation_type" => "remove"},
                timestamp: Time.zone.parse("2024-02-29T01:02:00").to_f
              }
            )

            expect(Fee.count).to eq(3)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(24)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("0.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(24) # (7 / 29) * 1
          end
        end
      end

      context "with in advance charge" do
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric:,
            prorated: false,
            pay_in_advance: true,
            properties: {amount: "1"}
          )
        end

        it "returns the expected result" do
          travel_to(DateTime.new(2024, 2, 23, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar",
                started_at: Time.zone.parse("2024-02-01T01:00:00")
              }
            )
          end

          subscription = customer.subscriptions.first

          travel_to(DateTime.new(2024, 2, 23, 1, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_1"},
                timestamp: Time.zone.parse("2024-02-23T01:02:00").to_f
              }
            )

            expect(Fee.count).to eq(1)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(100)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("1.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(100)
          end

          travel_to(DateTime.new(2024, 2, 26, 1, 1)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_1", "operation_type" => "remove"},
                timestamp: Time.zone.parse("2024-02-26T01:01:00").to_f
              }
            )

            expect(Fee.count).to eq(2)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(100)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("0.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(100)
          end

          travel_to(DateTime.new(2024, 2, 26, 1, 2)) do
            create_event(
              {
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                properties: {"item_id" => "seat_2"},
                timestamp: Time.zone.parse("2024-02-26T01:01:00").to_f
              }
            )

            expect(Fee.count).to eq(3)

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(100)
            expect(json[:customer_usage][:charges_usage].first[:units]).to eq("1.0")
            expect(json[:customer_usage][:charges_usage].first[:amount_cents]).to eq(100)
          end
        end
      end
    end
  end
end
