# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Standard Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

  context "with basic usage" do
    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "12.5"})
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
        4.times do
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
        expect(charge_usage[:units]).to eq("4.0")
        expect(charge_usage[:events_count]).to eq(4)
        expect(charge_usage[:amount_cents]).to eq(5000)
      end
    end
  end

  context "with grouped_by" do
    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "10", grouped_by: ["region"]})
    end

    it "returns grouped usage" do
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
        2.times do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {region: "us"}
            }
          )
        end
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {region: "eu"}
          }
        )

        fetch_current_usage(customer:)

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("3.0")
        expect(charge_usage[:amount_cents]).to eq(3000)

        grouped_usage = charge_usage[:grouped_usage]
        expect(grouped_usage.count).to eq(2)

        us_group = grouped_usage.find { |g| g[:grouped_by] == {region: "us"} }
        expect(us_group[:units]).to eq("2.0")
        expect(us_group[:amount_cents]).to eq(2000)

        eu_group = grouped_usage.find { |g| g[:grouped_by] == {region: "eu"} }
        expect(eu_group[:units]).to eq("1.0")
        expect(eu_group[:amount_cents]).to eq(1000)
      end
    end
  end

  context "with filters" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "hours") }

    before do
      cloud_filter = create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp])
      charge = create(:standard_charge, plan:, billable_metric:, properties: {amount: "0.12"})
      create(:charge_filter, charge:, properties: {amount: "0.10"}, invoice_display_name: "GCP")
        .tap { |cf| create(:charge_filter_value, charge_filter: cf, billable_metric_filter: cloud_filter, values: ["gcp"]) }
      create(:charge_filter, charge:, properties: {amount: "0.08"}, invoice_display_name: "AWS")
        .tap { |cf| create(:charge_filter_value, charge_filter: cf, billable_metric_filter: cloud_filter, values: ["aws"]) }
    end

    it "returns filtered usage" do
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
            properties: {cloud: "aws", hours: 100}
          }
        )
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {cloud: "gcp", hours: 200}
          }
        )

        fetch_current_usage(customer:)

        charge_usage = json[:customer_usage][:charges_usage].first
        # AWS: 100 * 0.08 = 800 cents, GCP: 200 * 0.10 = 2000 cents
        expect(charge_usage[:amount_cents]).to eq(2800)

        filters = charge_usage[:filters]
        aws_filter = filters.find { |f| f[:values] == {cloud: ["aws"]} }
        expect(aws_filter[:units]).to eq("100.0")
        expect(aws_filter[:amount_cents]).to eq(800)

        gcp_filter = filters.find { |f| f[:values] == {cloud: ["gcp"]} }
        expect(gcp_filter[:units]).to eq("200.0")
        expect(gcp_filter[:amount_cents]).to eq(2000)
      end
    end
  end
end
