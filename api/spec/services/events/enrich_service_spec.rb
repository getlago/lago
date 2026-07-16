# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::EnrichService do
  subject(:enrich_service) do
    described_class.new(event:, subscription:, billable_metric:, charges_and_filters:, persist:)
  end

  let(:organization) { create(:organization) }
  let(:subscription) { create(:subscription, organization:) }
  let(:plan) { subscription.plan }
  let(:billable_metric) { create(:sum_billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:charges_and_filters) { {charge => charge_filter} }
  let(:charge_filter) { nil }
  let(:persist) { true }

  let(:event) do
    create(
      :event,
      organization_id: organization.id,
      external_subscription_id: subscription.external_id,
      code: billable_metric.code,
      properties: {
        billable_metric.field_name => 12
      }
    )
  end

  describe "call" do
    it "creates an enriched event" do
      result = enrich_service.call

      expect(result).to be_success
      expect(result.enriched_events.count).to eq(1)

      enriched_event = result.enriched_events.first
      expect(enriched_event).to have_attributes(
        code: billable_metric.code,
        transaction_id: event.transaction_id,
        timestamp: be_within(1.second).of(event.timestamp),
        organization_id: organization.id,
        value: "12",
        decimal_value: 12.0,
        enriched_at: be_within(1.second).of(Time.current),
        charge_filter_id: nil,
        charge_id: charge.id,
        event_id: event.id,
        external_subscription_id: subscription.external_id,
        plan_id: plan.id,
        grouped_by: {}
      )
    end

    context "with a precise_total_amount_cents set on the event" do
      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => 12
          },
          precise_total_amount_cents: BigDecimal("1200.12")
        )
      end

      it "creates an enriched event with the precise_total_amount_cents" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event.precise_total_amount_cents).to eq(BigDecimal("1200.12"))
      end
    end

    context "when billable metric is uses a count aggregation" do
      let(:billable_metric) { create(:billable_metric, organization:) }

      it "creates an enriched event with value at 1" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event).to have_attributes(
          value: "1",
          decimal_value: 1.0
        )
      end
    end

    context "when event property is missing" do
      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {}
        )
      end

      it "creates an enriched event with value at 0" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event).to have_attributes(
          value: "0",
          decimal_value: 0.0
        )
      end
    end

    context "when event property is invalid" do
      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => "invalid_value"
          }
        )
      end

      it "creates an enriched event with value at 0" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event).to have_attributes(
          value: "invalid_value",
          decimal_value: 0.0
        )
      end
    end

    context "when billable metric uses a unique count aggregation" do
      let(:billable_metric) { create(:unique_count_billable_metric, organization:) }

      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => "foo_bar"
          }
        )
      end

      it "creates an enriched event with the right value and the operation type" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event.value).to eq("foo_bar")
        expect(enriched_event.operation_type).to eq("add")
      end

      context "when the event operation type is passed" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => "foo_bar",
              "operation_type" => "remove"
            }
          )
        end

        it "creates an enriched event with the right operation type" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event.value).to eq("foo_bar")
          expect(enriched_event.operation_type).to eq("remove")
        end
      end

      context "when the event operation type is unknown" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => "foo_bar",
              "operation_type" => "invalid"
            }
          )
        end

        it "creates an enriched event without the operation type" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event.value).to eq("foo_bar")
          expect(enriched_event.operation_type).to be_nil
        end
      end
    end

    context "when charges defines a pricing group key" do
      let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "120", pricing_group_keys: %w[cloud provider]}) }

      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => 12,
            "cloud" => "aws",
            "provider" => "visa"
          }
        )
      end

      it "creates an enriched event" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event.grouped_by).to eq({"cloud" => "aws", "provider" => "visa"})
      end

      context "when event does not hold the group keys" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => 12
            }
          )
        end

        it "creates an enriched event" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event.grouped_by).to eq({"cloud" => nil, "provider" => nil})
        end
      end
    end

    context "when the charge has the accepts_target_wallet flag set to true", :premium do
      let(:organization) { create(:organization, premium_integrations: ["events_targeting_wallets"]) }
      let(:charge) { create(:standard_charge, plan:, billable_metric:, accepts_target_wallet: true) }

      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => 12,
            "target_wallet_code" => "wallet1234"
          },
          precise_total_amount_cents: BigDecimal("1200.12")
        )
      end

      it "creates an enriched event with the target wallet code" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event.target_wallet_code).to eq("wallet1234")
        expect(enriched_event.grouped_by).to eq({"target_wallet_code" => "wallet1234"})
      end

      context "when the event does not have a target wallet code" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => 12,
              "region" => "eu"
            }
          )
        end

        it "creates an enriched event without the target wallet code" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event.target_wallet_code).to be_nil
          expect(enriched_event.grouped_by).to eq({})
        end
      end

      context "when charges defines a pricing group key" do
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric:,
            properties: {amount: "120", pricing_group_keys: %w[cloud provider]},
            accepts_target_wallet: true
          )
        end

        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => 12,
              "cloud" => "aws",
              "provider" => "visa",
              "target_wallet_code" => "wallet123"
            }
          )
        end

        it "creates an enriched event with both groups and target wallet code" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event.target_wallet_code).to eq("wallet123")
          expect(enriched_event.grouped_by).to eq({"cloud" => "aws", "provider" => "visa", "target_wallet_code" => "wallet123"})
        end
      end
    end

    context "when event matches a charge filter" do
      let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us eu]) }
      let(:charge_filter) { create(:charge_filter, charge:) }
      let(:charge_filter_value) { create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: %w[eu]) }

      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          properties: {
            billable_metric.field_name => 12,
            "region" => "eu"
          }
        )
      end

      before do
        charge_filter_value
      end

      it "creates an enriched event" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event).to have_attributes(
          charge_id: charge.id,
          charge_filter_id: charge_filter.id,
          grouped_by: {},
          value: "12",
          decimal_value: 12.0
        )
      end

      context "when filter has pricing group keys" do
        let(:charge_filter) { create(:charge_filter, charge:, properties: {amount: "120", pricing_group_keys: %w[cloud provider]}) }

        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {
              billable_metric.field_name => 12,
              "region" => "eu",
              "cloud" => "aws",
              "provider" => "visa"
            }
          )
        end

        it "creates an enriched event" do
          result = enrich_service.call

          expect(result).to be_success
          expect(result.enriched_events.count).to eq(1)

          enriched_event = result.enriched_events.first
          expect(enriched_event).to have_attributes(
            charge_id: charge.id,
            charge_filter_id: charge_filter.id,
            grouped_by: {
              "cloud" => "aws",
              "provider" => "visa"
            }
          )
        end
      end
    end

    context "when multiple charges matches the event" do
      let(:charge2) { create(:standard_charge, plan:, billable_metric:) }
      let(:charges_and_filters) { {charge => nil, charge2 => nil} }

      it "creates an enriched event for each charge" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(2)

        expect(result.enriched_events.pluck(:charge_id)).to match_array([charge.id, charge2.id])
      end
    end

    context "when persist flag is false" do
      let(:persist) { false }

      it "creates an enriched event without persisting it" do
        result = enrich_service.call

        expect(result).to be_success
        expect(result.enriched_events.count).to eq(1)

        enriched_event = result.enriched_events.first
        expect(enriched_event).not_to be_persisted
      end
    end
  end
end
