# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Package Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

  context "with basic package" do
    before do
      create(:package_charge, plan:, billable_metric:, properties: {amount: "100", free_units: 0, package_size: 10})
    end

    it "returns usage based on packages consumed" do
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
        # 3 units / 10 package_size = 1 package (ceil) * 100 = 10000 cents
        expect(charge_usage[:amount_cents]).to eq(10_000)
      end
    end

    it "returns usage for full packages" do
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
        # 15 / 10 = 2 packages * 100 = 20000 cents
        expect(charge_usage[:amount_cents]).to eq(20_000)
      end
    end
  end

  context "with free units" do
    before do
      create(:package_charge, plan:, billable_metric:, properties: {amount: "100", free_units: 5, package_size: 10})
    end

    it "excludes free units from charges" do
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
        # 3 units within 5 free units, so no charge
        expect(charge_usage[:amount_cents]).to eq(0)
      end
    end

    it "charges beyond free units" do
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
        12.times do
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
        expect(charge_usage[:units]).to eq("12.0")
        # 12 - 5 free = 7 billable / 10 package_size = 1 package * 100 = 10000 cents
        expect(charge_usage[:amount_cents]).to eq(10_000)
      end
    end
  end
end
