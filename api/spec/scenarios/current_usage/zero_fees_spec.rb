# frozen_string_literal: true

require "rails_helper"

describe "Current usage zero fees Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

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

  def expect_zero_charge_usage(charge_usage, charge_model:)
    expect(charge_usage[:units]).to eq("0.0")
    expect(charge_usage[:total_aggregated_units]).to eq("0.0")
    expect(charge_usage[:events_count]).to eq(0)
    expect(charge_usage[:amount_cents]).to eq(0)
    expect(charge_usage[:amount_currency]).to eq("EUR")
    expect(charge_usage[:pricing_unit_details]).to be_nil
    expect(charge_usage[:charge][:charge_model]).to eq(charge_model)
    expect(charge_usage[:charge][:lago_id]).to be_present
    expect(charge_usage[:charge][:invoice_display_name]).to be_present
    expect(charge_usage[:billable_metric][:lago_id]).to eq(billable_metric.id)
    expect(charge_usage[:billable_metric][:name]).to eq(billable_metric.name)
    expect(charge_usage[:billable_metric][:code]).to eq(billable_metric.code)
    expect(charge_usage[:billable_metric][:aggregation_type]).to eq(billable_metric.aggregation_type)
    expect(charge_usage[:grouped_usage]).to eq([])
  end

  def expect_zero_filter(filter)
    expect(filter[:units]).to eq("0.0")
    expect(filter[:total_aggregated_units]).to eq("0.0")
    expect(filter[:events_count]).to eq(0)
    expect(filter[:amount_cents]).to eq(0)
    expect(filter[:pricing_unit_details]).to be_nil
  end

  def expect_zero_customer_usage(customer_usage)
    expect(customer_usage[:amount_cents]).to eq(0)
    expect(customer_usage[:total_amount_cents]).to eq(0)
    expect(customer_usage[:taxes_amount_cents]).to eq(0)
    expect(customer_usage[:currency]).to eq("EUR")
    expect(customer_usage[:from_datetime]).to be_present
    expect(customer_usage[:to_datetime]).to be_present
    expect(customer_usage[:issuing_date]).to be_present
  end

  context "with standard charge model" do
    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "20"})
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "standard")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with graduated charge model" do
    before do
      create(
        :graduated_charge,
        plan:,
        billable_metric:,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
            {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
          ]
        }
      )
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "graduated")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with package charge model" do
    before do
      create(
        :package_charge,
        plan:,
        billable_metric:,
        properties: {amount: "100", free_units: 10, package_size: 10}
      )
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "package")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with percentage charge model" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    before do
      create(
        :percentage_charge,
        plan:,
        billable_metric:,
        properties: {rate: "0.05", fixed_amount: "2"}
      )
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "percentage")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with volume charge model" do
    before do
      create(
        :volume_charge,
        plan:,
        billable_metric:,
        properties: {
          volume_ranges: [
            {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"},
            {from_value: 101, to_value: nil, per_unit_amount: "1", flat_amount: "0"}
          ]
        }
      )
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "volume")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with graduated_percentage charge model", :premium do
    before do
      create(
        :graduated_percentage_charge,
        plan:,
        billable_metric:,
        properties: {
          graduated_percentage_ranges: [
            {from_value: 0, to_value: 10, rate: "1", flat_amount: "100"},
            {from_value: 11, to_value: nil, rate: "0.5", flat_amount: "50"}
          ]
        }
      )
    end

    it "returns zero usage" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "graduated_percentage")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with multiple charge models on the same plan" do
    let(:sum_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "20"})
      create(
        :graduated_charge,
        plan:,
        billable_metric: sum_metric,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
            {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
          ]
        }
      )
    end

    it "returns zero usage for each charge" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(2)

      charge_models = customer_usage[:charges_usage].map { |cu| cu[:charge][:charge_model] }
      expect(charge_models).to match_array(%w[standard graduated])

      customer_usage[:charges_usage].each do |charge_usage|
        expect(charge_usage[:units]).to eq("0.0")
        expect(charge_usage[:total_aggregated_units]).to eq("0.0")
        expect(charge_usage[:events_count]).to eq(0)
        expect(charge_usage[:amount_cents]).to eq(0)
        expect(charge_usage[:amount_currency]).to eq("EUR")
        expect(charge_usage[:filters]).to eq([])
        expect(charge_usage[:grouped_usage]).to eq([])
      end
    end
  end

  context "with pricing group keys" do
    before do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        properties: {amount: "20", grouped_by: ["region"]}
      )
    end

    it "returns zero usage with a zero grouped_usage entry" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("0.0")
      expect(charge_usage[:total_aggregated_units]).to eq("0.0")
      expect(charge_usage[:events_count]).to eq(0)
      expect(charge_usage[:amount_cents]).to eq(0)
      expect(charge_usage[:amount_currency]).to eq("EUR")
      expect(charge_usage[:filters]).to eq([])

      grouped_usage = charge_usage[:grouped_usage]
      expect(grouped_usage.count).to eq(1)

      group = grouped_usage.first
      expect(group[:grouped_by]).to eq({region: nil})
      expect(group[:units]).to eq("0.0")
      expect(group[:total_aggregated_units]).to eq("0.0")
      expect(group[:events_count]).to eq(0)
      expect(group[:amount_cents]).to eq(0)
      expect(group[:filters]).to eq([])
      expect(group[:pricing_unit_details]).to be_nil
    end

    context "when one group has usage" do
      it "returns grouped_usage with non-zero and zero groups" do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {region: "europe"}
          }
        )

        fetch_current_usage(customer:)

        customer_usage = json[:customer_usage]
        expect(customer_usage[:amount_cents]).to eq(2000)
        expect(customer_usage[:charges_usage].count).to eq(1)

        charge_usage = customer_usage[:charges_usage].first
        expect(charge_usage[:units]).to eq("1.0")
        expect(charge_usage[:amount_cents]).to eq(2000)

        grouped_usage = charge_usage[:grouped_usage]
        expect(grouped_usage.count).to eq(1)

        europe_group = grouped_usage.find { |g| g[:grouped_by] == {region: "europe"} }
        expect(europe_group[:units]).to eq("1.0")
        expect(europe_group[:total_aggregated_units]).to eq("1.0")
        expect(europe_group[:events_count]).to eq(1)
        expect(europe_group[:amount_cents]).to eq(2000)
        expect(europe_group[:filters]).to eq([])
        expect(europe_group[:pricing_unit_details]).to be_nil
      end
    end

    context "when multiple groups have usage" do
      it "returns grouped_usage for each group" do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {region: "europe"}
          }
        )
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {region: "usa"}
          }
        )

        fetch_current_usage(customer:)

        customer_usage = json[:customer_usage]
        expect(customer_usage[:amount_cents]).to eq(4000)
        expect(customer_usage[:charges_usage].count).to eq(1)

        charge_usage = customer_usage[:charges_usage].first
        expect(charge_usage[:units]).to eq("2.0")
        expect(charge_usage[:amount_cents]).to eq(4000)

        grouped_usage = charge_usage[:grouped_usage]
        expect(grouped_usage.count).to eq(2)

        europe_group = grouped_usage.find { |g| g[:grouped_by] == {region: "europe"} }
        expect(europe_group[:units]).to eq("1.0")
        expect(europe_group[:events_count]).to eq(1)
        expect(europe_group[:amount_cents]).to eq(2000)

        usa_group = grouped_usage.find { |g| g[:grouped_by] == {region: "usa"} }
        expect(usa_group[:units]).to eq("1.0")
        expect(usa_group[:events_count]).to eq(1)
        expect(usa_group[:amount_cents]).to eq(2000)
      end
    end
  end

  context "with charge filters" do
    let(:region) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa]) }

    let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"}) }
    let(:europe_filter) { create(:charge_filter, charge:, properties: {amount: "20"}) }
    let(:usa_filter) { create(:charge_filter, charge:, properties: {amount: "50"}) }

    before do
      create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
      create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
    end

    it "returns zero fees for all filters and catch-all" do
      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect_zero_customer_usage(customer_usage)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect_zero_charge_usage(charge_usage, charge_model: "standard")

      filters = charge_usage[:filters]
      expect(filters.count).to eq(3)

      filters.each { |filter| expect_zero_filter(filter) }

      filter_values = filters.map { |f| f[:values] }
      expect(filter_values).to match_array([{region: ["europe"]}, {region: ["usa"]}, nil])

      europe = filters.find { |f| f[:values] == {region: ["europe"]} }
      expect(europe[:invoice_display_name]).to eq(europe_filter.invoice_display_name)

      usa = filters.find { |f| f[:values] == {region: ["usa"]} }
      expect(usa[:invoice_display_name]).to eq(usa_filter.invoice_display_name)

      catch_all = filters.find { |f| f[:values].nil? }
      expect(catch_all[:invoice_display_name]).to be_nil
    end

    context "when one filter has usage" do
      it "returns non-zero fee for that filter and zero for others" do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {region: "europe"}
          }
        )

        fetch_current_usage(customer:)

        customer_usage = json[:customer_usage]
        expect(customer_usage[:amount_cents]).to eq(2000)
        expect(customer_usage[:total_amount_cents]).to eq(2000)
        expect(customer_usage[:charges_usage].count).to eq(1)

        charge_usage = customer_usage[:charges_usage].first
        expect(charge_usage[:units]).to eq("1.0")
        expect(charge_usage[:total_aggregated_units]).to eq("1.0")
        expect(charge_usage[:events_count]).to eq(1)
        expect(charge_usage[:amount_cents]).to eq(2000)
        expect(charge_usage[:amount_currency]).to eq("EUR")

        filters = charge_usage[:filters]
        expect(filters.count).to eq(3)

        europe = filters.find { |f| f[:values] == {region: ["europe"]} }
        expect(europe[:units]).to eq("1.0")
        expect(europe[:total_aggregated_units]).to eq("1.0")
        expect(europe[:events_count]).to eq(1)
        expect(europe[:amount_cents]).to eq(2000)

        zero_filters = filters.reject { |f| f[:values] == {region: ["europe"]} }
        expect(zero_filters.count).to eq(2)
        zero_filters.each { |filter| expect_zero_filter(filter) }

        zero_filter_values = zero_filters.map { |f| f[:values] }
        expect(zero_filter_values).to match_array([{region: ["usa"]}, nil])
      end
    end

    context "when fetching usage twice" do
      it "returns consistent results" do
        fetch_current_usage(customer:)
        first_response = json[:customer_usage]

        fetch_current_usage(customer:)
        second_response = json[:customer_usage]

        expect(second_response[:amount_cents]).to eq(first_response[:amount_cents])
        expect(second_response[:total_amount_cents]).to eq(first_response[:total_amount_cents])
        expect(second_response[:charges_usage].count).to eq(first_response[:charges_usage].count)

        first_filters = first_response[:charges_usage].first[:filters]
        second_filters = second_response[:charges_usage].first[:filters]
        expect(second_filters.count).to eq(first_filters.count)

        first_filters.zip(second_filters).each do |first_filter, second_filter|
          expect(second_filter[:units]).to eq(first_filter[:units])
          expect(second_filter[:events_count]).to eq(first_filter[:events_count])
          expect(second_filter[:amount_cents]).to eq(first_filter[:amount_cents])
          expect(second_filter[:values]).to eq(first_filter[:values])
        end
      end
    end
  end

  context "with events but zero amount (standard charge with amount 0)" do
    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "0"})
    end

    it "returns non-zero units and events with zero amount" do
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
      expect(customer_usage[:amount_cents]).to eq(0)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("3.0")
      expect(charge_usage[:total_aggregated_units]).to eq("3.0")
      expect(charge_usage[:events_count]).to eq(3)
      expect(charge_usage[:amount_cents]).to eq(0)
      expect(charge_usage[:charge][:charge_model]).to eq("standard")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with events but zero amount (package charge with free units covering usage)" do
    before do
      create(
        :package_charge,
        plan:,
        billable_metric:,
        properties: {amount: "100", free_units: 50, package_size: 10}
      )
    end

    it "returns non-zero units and events with zero amount when within free units" do
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
      expect(customer_usage[:amount_cents]).to eq(0)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("3.0")
      expect(charge_usage[:total_aggregated_units]).to eq("3.0")
      expect(charge_usage[:events_count]).to eq(3)
      expect(charge_usage[:amount_cents]).to eq(0)
      expect(charge_usage[:charge][:charge_model]).to eq("package")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with events but zero units (sum_agg with zero-value properties)" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    before do
      create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
    end

    it "returns non-zero events with zero units and zero amount" do
      3.times do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {value: 0}
          }
        )
      end

      fetch_current_usage(customer:)

      customer_usage = json[:customer_usage]
      expect(customer_usage[:amount_cents]).to eq(0)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("0.0")
      expect(charge_usage[:total_aggregated_units]).to eq("0.0")
      expect(charge_usage[:events_count]).to eq(3)
      expect(charge_usage[:amount_cents]).to eq(0)
      expect(charge_usage[:charge][:charge_model]).to eq("standard")
      expect(charge_usage[:filters]).to eq([])
    end
  end

  context "with charge filters where one filter has zero amount" do
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "hours") }

    let(:cloud) { create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp]) }

    let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "0.12"}) }
    let(:aws_filter) { create(:charge_filter, charge:, properties: {amount: "0"}) }
    let(:gcp_filter) { create(:charge_filter, charge:, properties: {amount: "0.10"}) }

    before do
      create(:charge_filter_value, charge_filter: aws_filter, billable_metric_filter: cloud, values: ["aws"])
      create(:charge_filter_value, charge_filter: gcp_filter, billable_metric_filter: cloud, values: ["gcp"])
    end

    it "returns mixed zero/non-zero amounts across filters" do
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

      customer_usage = json[:customer_usage]
      expect(customer_usage[:amount_cents]).to eq(2000)
      expect(customer_usage[:charges_usage].count).to eq(1)

      charge_usage = customer_usage[:charges_usage].first
      expect(charge_usage[:units]).to eq("300.0")
      expect(charge_usage[:events_count]).to eq(2)
      expect(charge_usage[:amount_cents]).to eq(2000)

      filters = charge_usage[:filters]
      expect(filters.count).to eq(3)

      aws = filters.find { |f| f[:values] == {cloud: ["aws"]} }
      expect(aws[:units]).to eq("100.0")
      expect(aws[:total_aggregated_units]).to eq("100.0")
      expect(aws[:events_count]).to eq(1)
      expect(aws[:amount_cents]).to eq(0)

      gcp = filters.find { |f| f[:values] == {cloud: ["gcp"]} }
      expect(gcp[:units]).to eq("200.0")
      expect(gcp[:total_aggregated_units]).to eq("200.0")
      expect(gcp[:events_count]).to eq(1)
      expect(gcp[:amount_cents]).to eq(2000)

      catch_all = filters.find { |f| f[:values].nil? }
      expect_zero_filter(catch_all)
    end
  end
end
