# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Customers::UsageResolver do
  let(:required_permission) { "customers:view" }
  let(:query) do
    <<~GQL
      query($customerId: ID!, $subscriptionId: ID!) {
        customerUsage(customerId: $customerId, subscriptionId: $subscriptionId) {
          fromDatetime
          toDatetime
          currency
          issuingDate
          amountCents
          totalAmountCents
          taxesAmountCents
          chargesUsage {
            billableMetric { name code aggregationType }
            charge { chargeModel }
            filters { id units amountCents pricingUnitAmountCents invoiceDisplayName values eventsCount presentationBreakdowns { presentationBy units } }
            units
            amountCents
            pricingUnitAmountCents
            groupedUsage {
              amountCents
              units
              eventsCount
              groupedBy
              filters { id units amountCents pricingUnitAmountCents invoiceDisplayName values eventsCount }
              presentationBreakdowns { presentationBy units }
            }
            presentationBreakdowns { presentationBy units }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, organization:, rate: 20) }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      started_at: Time.zone.now - 2.years
    )
  end
  let(:plan) { create(:plan, interval: "monthly") }

  let(:metric) { create(:billable_metric, name: "count_metric", aggregation_type: "count_agg") }
  let(:sum_metric) { create(:sum_billable_metric, name: "sum_metric", organization:) }
  let(:charge) do
    create(
      :graduated_charge,
      plan: subscription.plan,
      charge_model: "graduated",
      billable_metric: metric,
      properties: {
        graduated_ranges: [
          {
            from_value: 0,
            to_value: nil,
            per_unit_amount: "0.01",
            flat_amount: "0.01"
          }
        ]
      }
    )
  end
  let(:standard_charge) do
    create(
      :standard_charge,
      plan: subscription.plan,
      billable_metric: sum_metric,
      properties: {
        amount: 1.to_s,
        pricing_group_keys: ["agent_name"]
      }
    )
  end

  let(:billable_metric_filter) do
    create(:billable_metric_filter, billable_metric: sum_metric, key: "cloud", values: %w[aws gcp])
  end

  let(:charge_filter) { create(:charge_filter, charge: standard_charge, invoice_display_name: nil) }
  let(:charge_filter_value) do
    create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["aws"])
  end

  before do
    subscription
    charge
    tax
    charge_filter_value

    create(
      :applied_pricing_unit,
      organization: organization,
      conversion_rate: 0.25,
      pricing_unitable: standard_charge
    )

    create_list(
      :event,
      4,
      organization:,
      customer:,
      subscription:,
      code: metric.code,
      timestamp: Time.zone.now
    )

    create_list(
      :event,
      4,
      organization:,
      customer:,
      subscription:,
      code: sum_metric.code,
      timestamp: Time.zone.now,
      properties: {
        agent_name: "frodo",
        cloud: "aws",
        item_id: 1
      }
    )
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "customers:view"

  it "returns the usage for the customer" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        customerId: customer.id,
        subscriptionId: subscription.id
      }
    )

    usage_response = result["data"]["customerUsage"]

    expect(usage_response["fromDatetime"]).to eq(Time.current.beginning_of_month.iso8601)
    expect(usage_response["toDatetime"]).to eq(Time.current.end_of_month.iso8601)
    expect(usage_response["currency"]).to eq("EUR")
    expect(usage_response["issuingDate"]).to eq(Time.zone.today.end_of_month.iso8601)
    expect(usage_response["amountCents"]).to eq("105")
    expect(usage_response["totalAmountCents"]).to eq("105")
    expect(usage_response["taxesAmountCents"]).to eq("0")

    # Find graduated charge by charge model
    graduated_charge_usage = usage_response["chargesUsage"].find { |usage| usage["charge"]["chargeModel"] == "graduated" }
    expect(graduated_charge_usage["billableMetric"]["name"]).to eq(metric.name)
    expect(graduated_charge_usage["billableMetric"]["code"]).to eq(metric.code)
    expect(graduated_charge_usage["billableMetric"]["aggregationType"]).to eq("count_agg")
    expect(graduated_charge_usage["charge"]["chargeModel"]).to eq("graduated")
    expect(graduated_charge_usage["pricingUnitAmountCents"]).to eq(nil)
    expect(graduated_charge_usage["units"]).to eq(4.0)
    expect(graduated_charge_usage["amountCents"]).to eq("5")

    # Find standard charge by charge model
    standard_charge_usage = usage_response["chargesUsage"].find { |usage| usage["charge"]["chargeModel"] == "standard" }
    expect(standard_charge_usage["billableMetric"]["name"]).to eq(sum_metric.name)
    expect(standard_charge_usage["billableMetric"]["code"]).to eq(sum_metric.code)
    expect(standard_charge_usage["billableMetric"]["aggregationType"]).to eq("sum_agg")
    expect(standard_charge_usage["charge"]["chargeModel"]).to eq("standard")
    expect(standard_charge_usage["pricingUnitAmountCents"]).to eq("400")
    expect(standard_charge_usage["units"]).to eq(4.0)
    expect(standard_charge_usage["amountCents"]).to eq("100")

    grouped_usage = standard_charge_usage["groupedUsage"].first
    expect(grouped_usage["amountCents"]).to eq("100")
    expect(grouped_usage["pricingUnitAmountCents"]).to eq(nil)
    expect(grouped_usage["units"]).to eq(4.0)
    expect(grouped_usage["eventsCount"]).to eq(4)
    expect(grouped_usage["groupedBy"]).to eq({"agent_name" => "frodo"})
  end

  context "with presentation group keys" do
    let(:properties) do
      {
        amount: 1.to_s,
        presentation_group_keys: [{value: "cloud"}]
      }
    end
    let(:standard_charge) do
      create(
        :standard_charge,
        plan: subscription.plan,
        billable_metric: sum_metric,
        properties: properties
      )
    end

    it "returns the presentation breakdowns" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: customer.id,
          subscriptionId: subscription.id
        }
      )

      charges_usage = result["data"]["customerUsage"]["chargesUsage"]
      expect(charges_usage.first["presentationBreakdowns"]).to be_empty
      expect(charges_usage.second["filters"].first["presentationBreakdowns"]).to be_empty
      expect(charges_usage.second["filters"].second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
    end

    context "without charge filters" do
      let(:charge_filter_value) { nil }

      it "returns presentation breakdowns directly on the charge" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {
            customerId: customer.id,
            subscriptionId: subscription.id
          }
        )

        charges_usage = result["data"]["customerUsage"]["chargesUsage"]
        expect(charges_usage.first["presentationBreakdowns"]).to be_empty
        expect(charges_usage.first["filters"]).to be_empty
        expect(charges_usage.second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
        expect(charges_usage.second["filters"]).to be_empty
      end
    end

    context "with pricing group keys" do
      let(:properties) do
        {
          amount: 1.to_s,
          pricing_group_keys: ["item_id"],
          presentation_group_keys: [{value: "cloud"}]
        }
      end

      it "returns the presentation breakdowns" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {
            customerId: customer.id,
            subscriptionId: subscription.id
          }
        )

        charges_usage = result["data"]["customerUsage"]["chargesUsage"]
        expect(charges_usage.first["presentationBreakdowns"]).to be_empty
        expect(charges_usage.second["presentationBreakdowns"]).to be_empty

        grouped_usage = charges_usage.second["groupedUsage"]
        expect(grouped_usage.first["presentationBreakdowns"]).to be_empty
        expect(grouped_usage.second["presentationBreakdowns"]).to be_empty
        expect(charges_usage.second["filters"].second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
      end

      context "without charge filters" do
        let(:charge_filter_value) { nil }

        it "returns presentation breakdowns in grouped_usage" do
          result = execute_graphql(
            current_user: membership.user,
            current_organization: organization,
            permissions: required_permission,
            query:,
            variables: {
              customerId: customer.id,
              subscriptionId: subscription.id
            }
          )

          charges_usage = result["data"]["customerUsage"]["chargesUsage"]
          expect(charges_usage.second["presentationBreakdowns"]).to be_empty

          grouped_usage = charges_usage.second["groupedUsage"]
          expect(grouped_usage.first["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
        end
      end
    end

    context "with two charges without pricing_group_keys" do
      let(:presentation_metric) { create(:sum_billable_metric, organization:) }

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric: presentation_metric,
          properties: {
            amount: "1",
            presentation_group_keys: [{value: "cloud"}]
          }
        )
      end

      before do
        create_list(
          :event,
          3,
          organization:,
          customer:,
          subscription:,
          code: presentation_metric.code,
          timestamp: Time.zone.now,
          properties: {cloud: "gcp", item_id: 1}
        )
      end

      it "returns presentation breakdowns for both charges with no grouped_usage" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {
            customerId: customer.id,
            subscriptionId: subscription.id
          }
        )

        charges_usage = result["data"]["customerUsage"]["chargesUsage"]
        presentation_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == presentation_metric.code }
        sum_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == sum_metric.code }

        expect(presentation_charge_usage["groupedUsage"]).to be_empty
        expect(presentation_charge_usage["presentationBreakdowns"]).to eq([
          {"presentationBy" => {"cloud" => "gcp"}, "units" => "3.0"}
        ])

        expect(sum_charge_usage["groupedUsage"]).to be_empty
        expect(sum_charge_usage["presentationBreakdowns"]).to be_empty
        expect(sum_charge_usage["filters"].second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
      end

      context "without charge filters" do
        let(:charge_filter_value) { nil }

        it "returns presentation breakdowns directly on both charges" do
          result = execute_graphql(
            current_user: membership.user,
            current_organization: organization,
            permissions: required_permission,
            query:,
            variables: {
              customerId: customer.id,
              subscriptionId: subscription.id
            }
          )

          charges_usage = result["data"]["customerUsage"]["chargesUsage"]
          presentation_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == presentation_metric.code }
          sum_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == sum_metric.code }

          expect(presentation_charge_usage["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "gcp"}, "units" => "3.0"}])
          expect(sum_charge_usage["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
        end
      end
    end
  end

  context "with filters" do
    let(:cloud_bm_filter) do
      create(:billable_metric_filter, billable_metric: metric, key: "cloud", values: %w[aws google])
    end

    let(:aws_filter) do
      create(:charge_filter, charge:, properties: {amount: "10"})
    end
    let(:aws_filter_value) do
      create(:charge_filter_value, charge_filter: aws_filter, billable_metric_filter: cloud_bm_filter, values: ["aws"])
    end

    let(:google_filter) do
      create(:charge_filter, charge:, properties: {amount: "20"})
    end
    let(:google_filter_value) do
      create(
        :charge_filter_value,
        charge_filter: google_filter,
        billable_metric_filter: cloud_bm_filter,
        values: ["google"]
      )
    end

    let(:charge) do
      create(
        :standard_charge,
        plan: subscription.plan,
        billable_metric: metric,
        properties: {amount: "0"}
      )
    end

    before do
      aws_filter_value
      google_filter_value

      create(
        :applied_pricing_unit,
        organization: organization,
        conversion_rate: 0.2,
        pricing_unitable: charge
      )

      create_list(
        :event,
        3,
        organization:,
        customer:,
        subscription:,
        code: metric.code,
        timestamp: Time.zone.now,
        properties: {cloud: "aws"}
      )

      create(
        :event,
        organization:,
        customer:,
        subscription:,
        code: metric.code,
        timestamp: Time.zone.now,
        properties: {cloud: "google"}
      )
    end

    it "returns the filter usage for the customer" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: customer.id,
          subscriptionId: subscription.id
        }
      )

      charge_usage = result["data"]["customerUsage"]["chargesUsage"].find do |usage|
        usage["billableMetric"]["code"] == metric.code
      end

      filters_usage = charge_usage["filters"]

      expect(charge_usage["units"]).to eq(8)
      expect(charge_usage["amountCents"]).to eq("1000")
      expect(filters_usage).to contain_exactly(
        {
          "id" => nil,
          "units" => 4,
          "amountCents" => "0",
          "pricingUnitAmountCents" => "0",
          "invoiceDisplayName" => nil,
          "values" => {},
          "eventsCount" => 4,
          "presentationBreakdowns" => []
        },
        {
          "id" => aws_filter.id,
          "units" => 3,
          "amountCents" => "600",
          "pricingUnitAmountCents" => "3000",
          "invoiceDisplayName" => nil,
          "values" => {
            "cloud" => ["aws"]
          },
          "eventsCount" => 3,
          "presentationBreakdowns" => []
        },
        {
          "id" => google_filter.id,
          "units" => 1,
          "amountCents" => "400",
          "pricingUnitAmountCents" => "2000",
          "invoiceDisplayName" => nil,
          "values" => {
            "cloud" => ["google"]
          },
          "eventsCount" => 1,
          "presentationBreakdowns" => []
        }
      )
    end
  end
end
