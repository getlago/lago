# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::ProjectedUsageController, :premium do
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization, :premium) }

  let(:plan) { create(:plan, interval: "monthly") }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      started_at: Time.zone.now - 2.years
    )
  end

  describe "GET /customers/:customer_id/projected_usage" do
    subject do
      get_with_token(
        organization,
        "/api/v1/customers/#{customer.external_id}/projected_usage",
        params
      )
    end

    let(:params) { {external_subscription_id: subscription.external_id} }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
    let(:metric) { create(:billable_metric, aggregation_type: "count_agg") }

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

    before do
      subscription
      charge
      tax

      travel_to(Time.parse("2025-07-02T10:00:00Z")) do
        create_list(
          :event,
          4,
          organization:,
          customer:,
          subscription:,
          code: metric.code,
          timestamp: Time.zone.now
        )
      end
    end

    include_examples "requires API permission", "customer_usage", "read"

    describe "premium permissions" do
      before do
        organization.update!(premium_integrations:)
        subject
      end

      context "when organization has 'projected_usage' premium integration" do
        let(:premium_integrations) { organization.premium_integrations.including("projected_usage") }

        context "when organization has 'projected_usage' premium integration" do
          it "does not return 403 Forbidden" do
            expect(response).not_to have_http_status(:forbidden)
          end
        end
      end

      context "when organization does not have 'projected_usage' premium integration" do
        let(:premium_integrations) { organization.premium_integrations.excluding("projected_usage") }

        context "when organization does not have 'projected_usage' premium integration" do
          it "does not return 403 Forbidden" do
            expect(response).to have_http_status(:forbidden)
            expect(json).to match hash_including(code: "projected_usage_not_enabled")
          end
        end
      end
    end

    it "returns the projected usage for the customer" do
      travel_to(Time.parse("2025-07-03T10:00:00Z")) do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:customer_projected_usage][:from_datetime]).to eq(Time.zone.today.beginning_of_month.beginning_of_day.iso8601)
        expect(json[:customer_projected_usage][:to_datetime]).to eq(Time.zone.today.end_of_month.end_of_day.iso8601)
        expect(json[:customer_projected_usage][:issuing_date]).to eq(Time.zone.today.end_of_month.iso8601)
        expect(json[:customer_projected_usage][:amount_cents]).to eq(5)
        expect(json[:customer_projected_usage][:currency]).to eq("EUR")
        expect(json[:customer_projected_usage][:total_amount_cents]).to eq(6)
        expect(json[:customer_projected_usage][:projected_amount_cents]).to be_present

        charge_usage = json[:customer_projected_usage][:charges_usage].first
        expect(charge_usage[:billable_metric][:name]).to eq(metric.name)
        expect(charge_usage[:billable_metric][:code]).to eq(metric.code)
        expect(charge_usage[:billable_metric][:aggregation_type]).to eq("count_agg")
        expect(charge_usage[:charge][:charge_model]).to eq("graduated")
        expect(charge_usage[:units]).to eq("4.0")
        expect(charge_usage[:amount_cents]).to eq(5)
        expect(charge_usage[:amount_currency]).to eq("EUR")
        expect(charge_usage[:projected_units]).to be_present
        expect(charge_usage[:projected_amount_cents]).to be_present
      end
    end

    context "when apply_taxes is false" do
      let(:params) { {external_subscription_id: subscription.external_id, apply_taxes: false} }

      it "returns the projected usage for the customer without applying taxes" do
        travel_to(Time.parse("2025-07-03T10:00:00Z")) do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:customer_projected_usage][:amount_cents]).to eq(5)
          expect(json[:customer_projected_usage][:taxes_amount_cents]).to eq(0)
          expect(json[:customer_projected_usage][:total_amount_cents]).to eq(5)
          expect(json[:customer_projected_usage][:projected_amount_cents]).to be_present
        end
      end
    end

    context "when apply_taxes is true" do
      let(:params) { {external_subscription_id: subscription.external_id, apply_taxes: true} }

      context "with a anrok provider" do
        let(:integration) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
        let(:double_checker) { instance_double(Throttling::Base) }

        before {
          integration_customer
          allow(Throttling).to receive(:for).with(:anrok).and_return(double_checker)
          allow(double_checker).to receive(:check).and_return(false)
        }

        it "rescue from provider throttles" do
          travel_to(Time.parse("2025-07-03T10:00:00Z")) do
            subject
            expect(response).to have_http_status(:too_many_requests)
            expect(response.body).to match(/anrok.*Try again later/)
          end
        end
      end
    end

    context "with filters" do
      let(:filter_metric) { create(:billable_metric, aggregation_type: "count_agg", organization:) }
      let(:billable_metric_filter) do
        create(:billable_metric_filter, billable_metric: filter_metric, key: "cloud", values: %w[aws google])
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric: filter_metric,
          properties: {amount: "0"}
        )
      end

      let(:charge_filter_aws) { create(:charge_filter, charge:, properties: {amount: "10"}) }
      let(:charge_filter_gcp) { create(:charge_filter, charge:, properties: {amount: "20"}) }

      let(:charge_filter_value_aws) do
        create(:charge_filter_value, charge_filter: charge_filter_aws, billable_metric_filter:, values: ["aws"])
      end

      let(:charge_filter_value_gcp) do
        create(:charge_filter_value, charge_filter: charge_filter_gcp, billable_metric_filter:, values: ["google"])
      end

      before do
        subscription
        charge
        tax
        charge_filter_value_aws
        charge_filter_value_gcp

        travel_to(Time.parse("2025-07-02T10:00:00Z")) do
          create_list(
            :event,
            3,
            organization:,
            customer:,
            subscription:,
            code: filter_metric.code,
            timestamp: Time.zone.now,
            properties: {cloud: "aws"}
          )

          create(
            :event,
            organization:,
            customer:,
            subscription:,
            code: filter_metric.code,
            timestamp: Time.zone.now,
            properties: {cloud: "google"}
          )
        end
      end

      it "returns the projected filters usage for the customer" do
        travel_to(Time.parse("2025-07-03T10:00:00Z")) do
          subject

          charge_usage = json[:customer_projected_usage][:charges_usage].first
          filters_usage = charge_usage[:filters]

          aws_filter_data = filters_usage.find { |f| f[:values] && f[:values][:cloud] == ["aws"] }
          gcp_filter_data = filters_usage.find { |f| f[:values] && f[:values][:cloud] == ["google"] }

          expect(charge_usage[:units]).to eq("4.0")
          expect(charge_usage[:amount_cents]).to eq(5000)
          expect(charge_usage[:projected_units]).to be_present
          expect(charge_usage[:projected_amount_cents]).to be_present

          # Assertions for the AWS filter
          expect(aws_filter_data[:units]).to eq("3.0")
          expect(aws_filter_data[:amount_cents]).to eq(3000)
          expect(aws_filter_data[:projected_units]).to eq("31.0")
          expect(aws_filter_data[:projected_amount_cents]).to eq(31000)

          # Assertions for the GCP filter
          expect(gcp_filter_data[:units]).to eq("1.0")
          expect(gcp_filter_data[:amount_cents]).to eq(2000)
          expect(gcp_filter_data[:projected_units]).to eq("10.33")
          expect(gcp_filter_data[:projected_amount_cents]).to eq(20660)
        end
      end
    end

    context "when customer does not belongs to the organization" do
      let(:customer) { create(:customer) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
