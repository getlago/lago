# frozen_string_literal: true

require "rails_helper"

describe "Current usage pricing unit Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:pricing_unit) { create(:pricing_unit, organization:, code: "credits", short_name: "CRD") }

  around { |test| travel_to(DateTime.new(2024, 3, 5)) { test.run } }

  before do
    create_subscription(
      {
        external_customer_id: customer.external_id,
        external_id: customer.external_id,
        plan_code: plan.code
      }
    )
  end

  context "with standard charge and events" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "credits") }

    before do
      charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "1.0"})
      create(
        :applied_pricing_unit,
        organization:,
        pricing_unit:,
        pricing_unitable: charge,
        conversion_rate: 0.5
      )
    end

    it "returns pricing_unit_details in current usage" do
      3.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {credits: 100}
          }
        )
      end

      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      # 300 units × 1.0 pricing_unit/unit = 300 pricing_units × 0.5 EUR/pricing_unit = 150 EUR = 15000 cents
      expect(charge_usage[:units]).to eq("300.0")
      expect(charge_usage[:events_count]).to eq(3)
      expect(charge_usage[:amount_cents]).to eq(15_000)

      pricing_details = charge_usage[:pricing_unit_details]
      expect(pricing_details).not_to be_nil
      expect(pricing_details[:short_name]).to eq("CRD")
      expect(pricing_details[:conversion_rate]).to eq("0.5")
      # 300 units × 1.0 = 300 pricing_units = 30000 pricing_unit cents
      expect(pricing_details[:amount_cents]).to eq(30_000)
    end
  end

  context "with zero usage" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

    before do
      charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "5.0"})
      create(
        :applied_pricing_unit,
        organization:,
        pricing_unit:,
        pricing_unitable: charge,
        conversion_rate: 0.5
      )
    end

    it "returns pricing_unit_details with zero values" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("0.0")
      expect(charge_usage[:events_count]).to eq(0)
      expect(charge_usage[:amount_cents]).to eq(0)

      pricing_details = charge_usage[:pricing_unit_details]
      expect(pricing_details).not_to be_nil
      expect(pricing_details[:short_name]).to eq("CRD")
      expect(pricing_details[:conversion_rate]).to eq("0.5")
      expect(pricing_details[:amount_cents]).to eq(0)
    end
  end

  context "with grouped_by" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "credits") }

    before do
      charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "1.0", grouped_by: ["region"]})
      create(
        :applied_pricing_unit,
        organization:,
        pricing_unit:,
        pricing_unitable: charge,
        conversion_rate: 0.5
      )
    end

    it "returns pricing_unit_details at top level and in grouped_usage" do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {credits: 100, region: "us"}
        }
      )
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {credits: 200, region: "eu"}
        }
      )

      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      # Total: 300 units × 1.0 × 0.5 = 150 EUR = 15000 cents
      expect(charge_usage[:amount_cents]).to eq(15_000)

      pricing_details = charge_usage[:pricing_unit_details]
      expect(pricing_details).not_to be_nil
      expect(pricing_details[:short_name]).to eq("CRD")
      expect(pricing_details[:amount_cents]).to eq(30_000)

      grouped_usage = charge_usage[:grouped_usage]
      expect(grouped_usage.count).to eq(2)

      us_group = grouped_usage.find { |g| g[:grouped_by] == {region: "us"} }
      expect(us_group[:units]).to eq("100.0")
      expect(us_group[:amount_cents]).to eq(5_000)
      expect(us_group[:pricing_unit_details]).not_to be_nil
      expect(us_group[:pricing_unit_details][:short_name]).to eq("CRD")
      expect(us_group[:pricing_unit_details][:amount_cents]).to eq(10_000)

      eu_group = grouped_usage.find { |g| g[:grouped_by] == {region: "eu"} }
      expect(eu_group[:units]).to eq("200.0")
      expect(eu_group[:amount_cents]).to eq(10_000)
      expect(eu_group[:pricing_unit_details]).not_to be_nil
      expect(eu_group[:pricing_unit_details][:short_name]).to eq("CRD")
      expect(eu_group[:pricing_unit_details][:amount_cents]).to eq(20_000)
    end
  end

  context "without applied_pricing_unit" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
    end

    it "returns nil pricing_unit_details" do
      create_event(
        {
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id
        }
      )

      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("1.0")
      expect(charge_usage[:amount_cents]).to eq(1000)
      expect(charge_usage[:pricing_unit_details]).to be_nil
    end
  end
end
