# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::Customers::UsageResolver do
  let(:now) { Time.zone.parse("2025-06-15").in_time_zone }
  let(:timestamp) { now }
  let(:query) do
    <<~GQL
      query($subscriptionId: ID!) {
        customerPortalCustomerUsage(subscriptionId: $subscriptionId) {
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
            filters { id units amountCents invoiceDisplayName values eventsCount presentationBreakdowns { presentationBy units } }
            units
            amountCents
            groupedUsage {
              amountCents
              units
              eventsCount
              groupedBy
              filters { id units amountCents invoiceDisplayName values eventsCount }
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
      started_at: now - 2.years
    )
  end
  let(:plan) { create(:plan, interval: "monthly") }

  let(:metric) { create(:billable_metric, aggregation_type: "count_agg") }
  let(:sum_metric) { create(:sum_billable_metric, organization:) }
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
        grouped_by: ["agent_name"]
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

    create_list(
      :event,
      4,
      organization:,
      customer:,
      subscription:,
      code: metric.code,
      timestamp: now - 1.hour
    )

    create_list(
      :event,
      4,
      organization:,
      customer:,
      subscription:,
      code: sum_metric.code,
      timestamp: now - 1.hour,
      properties: {
        agent_name: "frodo",
        cloud: "aws",
        item_id: 1
      }
    )
  end

  it_behaves_like "requires a customer portal user"

  it "returns the usage for the customer" do
    travel_to(now) do
      Subscriptions::ChargeCacheService.expire_for_subscription(subscription)
      result = execute_graphql(
        customer_portal_user: customer,
        query:,
        variables: {
          subscriptionId: subscription.id
        }
      )

      usage_response = result["data"]["customerPortalCustomerUsage"]

      expect(usage_response["fromDatetime"]).to eq(now.beginning_of_month.iso8601)
      expect(usage_response["toDatetime"]).to eq(now.end_of_month.iso8601)
      expect(usage_response["currency"]).to eq("EUR")
      expect(usage_response["issuingDate"]).to eq(now.to_date.end_of_month.iso8601)
      expect(usage_response["amountCents"]).to eq("405")
      expect(usage_response["totalAmountCents"]).to eq("405")
      expect(usage_response["taxesAmountCents"]).to eq("0")
      charge_usage = usage_response["chargesUsage"].find { |usage| usage["billableMetric"]["code"] == metric.code }
      expect(charge_usage["billableMetric"]["name"]).to eq(metric.name)
      expect(charge_usage["billableMetric"]["aggregationType"]).to eq("count_agg")
      expect(charge_usage["charge"]["chargeModel"]).to eq("graduated")
      expect(charge_usage["units"]).to eq(4.0)
      expect(charge_usage["amountCents"]).to eq("5")
      charge_usage = usage_response["chargesUsage"].find { |usage| usage["billableMetric"]["code"] == sum_metric.code }
      expect(charge_usage["billableMetric"]["name"]).to eq(sum_metric.name)
      expect(charge_usage["billableMetric"]["aggregationType"]).to eq("sum_agg")
      expect(charge_usage["charge"]["chargeModel"]).to eq("standard")
      expect(charge_usage["units"]).to eq(4.0)
      expect(charge_usage["amountCents"]).to eq("400")
      grouped_usage = charge_usage["groupedUsage"].first
      expect(grouped_usage["amountCents"]).to eq("400")
      expect(grouped_usage["units"]).to eq(4.0)
      expect(grouped_usage["eventsCount"]).to eq(4)
      expect(grouped_usage["groupedBy"]).to eq({"agent_name" => "frodo"})
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

      create_list(
        :event,
        3,
        organization:,
        customer:,
        subscription:,
        code: metric.code,
        timestamp: now - 1.hour,
        properties: {cloud: "aws"}
      )

      create(
        :event,
        organization:,
        customer:,
        subscription:,
        code: metric.code,
        timestamp: now - 1.hour,
        properties: {cloud: "google"}
      )
    end

    it "returns the filter usage for the customer" do
      travel_to(now) do
        result = execute_graphql(
          customer_portal_user: customer,
          query:,
          variables: {
            subscriptionId: subscription.id
          }
        )

        charge_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"].find do |usage|
          usage["billableMetric"]["code"] == metric.code
        end
        filters_usage = charge_usage["filters"]

        expect(charge_usage["units"]).to eq(8)
        expect(charge_usage["amountCents"]).to eq("5000")
        expect(filters_usage).to contain_exactly(
          {
            "id" => nil,
            "units" => 4,
            "amountCents" => "0",
            "invoiceDisplayName" => nil,
            "values" => {},
            "eventsCount" => 4,
            "presentationBreakdowns" => []
          },
          {
            "id" => aws_filter.id,
            "units" => 3,
            "amountCents" => "3000",
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
            "amountCents" => "2000",
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

  context "with presentation group keys" do
    let(:standard_charge) do
      create(
        :standard_charge,
        plan: subscription.plan,
        billable_metric: sum_metric,
        properties: {
          amount: 1.to_s,
          presentation_group_keys: [{value: "cloud"}]
        }
      )
    end

    it "returns the presentation breakdowns" do
      travel_to(now) do
        Subscriptions::ChargeCacheService.expire_for_subscription(subscription)
        result = execute_graphql(
          customer_portal_user: customer,
          query:,
          variables: {
            subscriptionId: subscription.id
          }
        )

        charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
        sum_charge_usage = charges_usage.find { |usage| usage["billableMetric"]["code"] == sum_metric.code }
        expect(sum_charge_usage["presentationBreakdowns"]).to be_empty
        expect(sum_charge_usage["filters"].first["presentationBreakdowns"]).to be_empty
        expect(sum_charge_usage["filters"].second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
        metric_charge_usage = charges_usage.find { |usage| usage["billableMetric"]["code"] == metric.code }
        expect(metric_charge_usage["presentationBreakdowns"]).to be_empty
      end
    end

    context "without charge filters" do
      let(:charge_filter_value) { nil }

      before { standard_charge }

      it "returns presentation breakdowns directly on the charge" do
        travel_to(now) do
          result = execute_graphql(
            customer_portal_user: customer,
            query:,
            variables: {
              subscriptionId: subscription.id
            }
          )

          charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
          sum_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == sum_metric.code }
          expect(sum_charge_usage["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
        end
      end
    end

    context "with pricing group keys" do
      let(:standard_charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric: sum_metric,
          properties: {
            amount: 1.to_s,
            pricing_group_keys: ["item_id"],
            presentation_group_keys: [{value: "cloud"}]
          }
        )
      end

      it "returns the presentation breakdowns" do
        travel_to(now) do
          Subscriptions::ChargeCacheService.expire_for_subscription(subscription)
          result = execute_graphql(
            customer_portal_user: customer,
            query:,
            variables: {
              subscriptionId: subscription.id
            }
          )

          charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
          sum_charge = charges_usage.find { |usage| usage["billableMetric"]["code"] == sum_metric.code }
          expect(sum_charge["presentationBreakdowns"]).to be_empty

          grouped_usage = sum_charge["groupedUsage"]
          expect(grouped_usage.first["presentationBreakdowns"]).to be_empty
          expect(grouped_usage.second["presentationBreakdowns"]).to be_empty
          expect(sum_charge["filters"].second["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])

          metric_charge = charges_usage.find { |usage| usage["billableMetric"]["code"] == metric.code }
          expect(metric_charge["presentationBreakdowns"]).to be_empty
        end
      end

      context "without charge filters" do
        let(:charge_filter_value) { nil }

        before { standard_charge }

        it "returns presentation breakdowns in grouped_usage" do
          travel_to(now) do
            result = execute_graphql(
              customer_portal_user: customer,
              query:,
              variables: {
                subscriptionId: subscription.id
              }
            )

            charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
            sum_charge = charges_usage.find { |u| u["billableMetric"]["code"] == sum_metric.code }
            expect(sum_charge["presentationBreakdowns"]).to be_empty

            grouped_usage = sum_charge["groupedUsage"]
            expect(grouped_usage.first["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
          end
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
          timestamp: now - 1.hour,
          properties: {cloud: "gcp", item_id: 1}
        )
      end

      it "returns presentation breakdowns for both charges with no grouped_usage" do
        travel_to(now) do
          Subscriptions::ChargeCacheService.expire_for_subscription(subscription)
          result = execute_graphql(
            customer_portal_user: customer,
            query:,
            variables: {
              subscriptionId: subscription.id
            }
          )

          charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
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
      end

      context "without charge filters" do
        let(:charge_filter_value) { nil }

        before { standard_charge }

        it "returns presentation breakdowns directly on both charges" do
          travel_to(now) do
            result = execute_graphql(
              customer_portal_user: customer,
              query:,
              variables: {
                subscriptionId: subscription.id
              }
            )

            charges_usage = result["data"]["customerPortalCustomerUsage"]["chargesUsage"]
            presentation_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == presentation_metric.code }
            sum_charge_usage = charges_usage.find { |u| u["billableMetric"]["code"] == sum_metric.code }

            expect(presentation_charge_usage["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "gcp"}, "units" => "3.0"}])
            expect(sum_charge_usage["presentationBreakdowns"]).to eq([{"presentationBy" => {"cloud" => "aws"}, "units" => "4.0"}])
          end
        end
      end
    end
  end
end
