# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Graduated Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
  let(:sum_billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "amount") }
  let(:recurring_sum_billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "amount", recurring: true) }

  before { tax }

  describe "with sum_agg" do
    describe "non-prorated graduated with no events (ING-13 regression)" do
      it "returns zero customer usage without raising" do
        travel_to(DateTime.new(2024, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          plan:,
          billable_metric: sum_billable_metric,
          properties: {
            graduated_ranges: [
              {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
              {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
            ]
          }
        )

        travel_to(DateTime.new(2024, 3, 6)) do
          # First call exercises the previously-crashing hydrate_non_persistable_fees path
          # for current usage when there are no persistable fees.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)

          # Second call proves stability across repeated invocations, matching the
          # daily DailyUsages::ComputeJob invocation pattern.
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)
        end
      end
    end

    describe "prorated graduated with no events (ING-13 regression)" do
      it "returns zero customer usage without raising (factory falls back from ProratedGraduatedService to GraduatedService)" do
        travel_to(DateTime.new(2024, 3, 5)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          plan:,
          billable_metric: recurring_sum_billable_metric,
          prorated: true,
          properties: {
            graduated_ranges: [
              {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
              {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
            ]
          }
        )

        travel_to(DateTime.new(2024, 3, 6)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(0)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
          expect(json[:customer_usage][:charges_usage][0][:amount_cents]).to eq(0)
        end
      end
    end
  end

  context "with basic graduated ranges" do
    before do
      create(
        :graduated_charge,
        plan:,
        billable_metric:,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 5, per_unit_amount: "10", flat_amount: "100"},
            {from_value: 6, to_value: nil, per_unit_amount: "5", flat_amount: "50"}
          ]
        }
      )
    end

    it "returns usage within first range" do
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

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("3.0")
        # 3 * 10 + 100 = 130 => 13000 cents
        expect(charge_usage[:amount_cents]).to eq(13_000)
      end
    end

    it "returns usage spanning multiple ranges" do
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
        8.times do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id
            }
          )
        end

        fetch_current_usage(customer:)

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("8.0")
        # Range 1: 5 * 10 + 100 = 150
        # Range 2: 3 * 5 + 50 = 65
        # Total: 215 => 21500 cents
        expect(charge_usage[:amount_cents]).to eq(21_500)
      end
    end
  end
end
