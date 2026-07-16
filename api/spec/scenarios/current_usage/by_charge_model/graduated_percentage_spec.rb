# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Graduated Percentage Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "amount") }

  context "with basic graduated percentage ranges" do
    before do
      create(
        :graduated_percentage_charge,
        plan:,
        billable_metric:,
        properties: {
          graduated_percentage_ranges: [
            {from_value: 0, to_value: 100, rate: "5", flat_amount: "0"},
            {from_value: 101, to_value: nil, rate: "2", flat_amount: "10"}
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
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "50"}
          }
        )

        fetch_current_usage(customer:)

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("50.0")
        # 50 * 5% = 2.5 => 250 cents
        expect(charge_usage[:amount_cents]).to eq(250)
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
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "150"}
          }
        )

        fetch_current_usage(customer:)

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("150.0")
        # Range 1: 100 * 5% + 0 = 5.0
        # Range 2: 50 * 2% + 10 = 11.0
        # Total: 16.0 => 1600 cents
        expect(charge_usage[:amount_cents]).to eq(1600)
      end
    end
  end
end
