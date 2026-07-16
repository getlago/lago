# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Volume Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

  context "with basic volume ranges" do
    before do
      create(
        :volume_charge,
        plan:,
        billable_metric:,
        properties: {
          volume_ranges: [
            {from_value: 0, to_value: 10, per_unit_amount: "5", flat_amount: "100"},
            {from_value: 11, to_value: nil, per_unit_amount: "2", flat_amount: "50"}
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
        5.times do
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
        expect(charge_usage[:units]).to eq("5.0")
        # 5 * 5 + 100 = 125 => 12500 cents
        expect(charge_usage[:amount_cents]).to eq(12_500)
      end
    end

    it "returns usage in second range" do
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
        15.times do
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
        expect(charge_usage[:units]).to eq("15.0")
        # Volume: all units priced at second range: 15 * 2 + 50 = 80 => 8000 cents
        expect(charge_usage[:amount_cents]).to eq(8_000)
      end
    end
  end
end
