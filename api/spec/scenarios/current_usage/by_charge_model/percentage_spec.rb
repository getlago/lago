# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Percentage Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }

  let(:plan) { create(:plan, organization:, amount_cents: 1000) }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type:, field_name:) }

  before { tax }

  describe "with sum_agg" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    describe "with free_units_per_events and fixed_amount" do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {rate: "1", fixed_amount: "5", free_units_per_events: 3}
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("20.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("30.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(510)
          expect(json[:customer_usage][:total_amount_cents]).to eq(612)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("40.0")
        end
      end
    end

    describe "with free_units_per_total_aggregation and fixed_amount" do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {rate: "1", fixed_amount: "5", free_units_per_total_aggregation: "15.0"}
        )

        travel_to(DateTime.new(2023, 3, 6, 0, 1)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "4"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("4.0")
        end

        travel_to(DateTime.new(2023, 3, 6, 0, 2)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "4"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("8.0")
        end

        travel_to(DateTime.new(2023, 3, 6, 0, 3)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "4"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("12.0")
        end

        travel_to(DateTime.new(2023, 3, 6, 0, 4)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "4"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(501)
          expect(json[:customer_usage][:total_amount_cents]).to eq(601)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("16.0")
        end

        travel_to(DateTime.new(2023, 3, 6, 0, 5)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(1011)
          expect(json[:customer_usage][:total_amount_cents]).to eq(1213)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("26.0")
        end
      end
    end

    describe "with free_units_per_events, free_units_per_total_aggregation and fixed_amount (events overage)" do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "5",
            free_units_per_events: 3,
            free_units_per_total_aggregation: "15.0"
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("3.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(501)
          expect(json[:customer_usage][:total_amount_cents]).to eq(601)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("4.0")
        end
      end
    end

    describe "with free_units_per_events, free_units_per_total_aggregation and fixed_amount (total_agg overage)" do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "5",
            free_units_per_events: 3,
            free_units_per_total_aggregation: "15.0"
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(505)
          expect(json[:customer_usage][:total_amount_cents]).to eq(606)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("20.0")

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"}
            }
          )
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents]).to eq(1015)
          expect(json[:customer_usage][:total_amount_cents]).to eq(1218)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("30.0")
        end
      end
    end

    describe "with min and max per transaction amount", :premium do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "1",
            per_transaction_max_amount: "12",
            per_transaction_min_amount: "1.75"
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "100"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(240)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(200)

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1000"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(1560)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(1300)

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10000"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(3000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("11100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(2500)
        end
      end
    end

    describe "with min and max per transaction amount and pricing group keys", :premium do
      it "returns the expected customer usage" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "1",
            per_transaction_max_amount: "12",
            per_transaction_min_amount: "1.75",
            pricing_group_keys: ["region", "provider"]
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "100", region: "US", provider: "AWS"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(240)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(200)
          expect(json[:customer_usage][:charges_usage][0][:grouped_usage].first[:grouped_by]).to eq({region: "US", provider: "AWS"})

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "1000", region: "US", provider: "AWS"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(1560)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(1300)

          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10000", region: "US", provider: "AWS"}
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(3000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("11100.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(2500)
        end
      end
    end

    describe "with min and max per transaction amount and no events (ING-13 regression)", :premium do
      it "returns a zero customer usage without raising NoMethodError" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "1",
            per_transaction_max_amount: "12",
            per_transaction_min_amount: "1.75"
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          # First call: the cache middleware returns an empty hydrated-fee array.
          # This used to crash in ChargeModels::PercentageService because
          # result.aggregator was nil.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)

          # Second call: exercises the cached-empty path again, matching how
          # DailyUsages::ComputeJob repeatedly invoked the usage pipeline in production.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)
        end
      end
    end

    describe "with min and max per transaction amount, pricing group keys and no events (ING-13 grouped regression)", :premium do
      it "returns zero customer usage without raising NoMethodError through the grouped hydrate path" do
        travel_to(DateTime.new(2023, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "1",
            per_transaction_max_amount: "12",
            per_transaction_min_amount: "1.75",
            pricing_group_keys: ["region", "provider"]
          }
        )

        travel_to(DateTime.new(2023, 3, 6)) do
          # First call exercises the grouped hydrate path: ChargeModels::GroupedService
          # copies the outer aggregator onto each inner aggregation. Before the fix the
          # outer result.aggregator stayed nil for grouped charges, reintroducing the
          # NoMethodError despite the ungrouped path being patched.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")

          # Second call exercises the cached-empty grouped path, matching how
          # DailyUsages::ComputeJob repeatedly invoked the usage pipeline in production.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
        end
      end
    end
  end
end
