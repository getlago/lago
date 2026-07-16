# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::CreatePayInAdvanceService do
  subject(:fee_service) { described_class.new(charge:, event:, billing_at: event.timestamp, estimate:) }

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:estimate) { false }

  let(:charge_filter) { nil }

  let(:charge) { create(:standard_charge, :pay_in_advance, billable_metric:, plan:) }

  let(:event) do
    source = create(
      :event,
      external_subscription_id: subscription.external_id,
      external_customer_id: customer.external_id,
      organization_id: organization.id,
      properties: event_properties
    )
    Events::CommonFactory.new_instance(source:)
  end

  let(:event_properties) { {} }

  before { tax }

  describe "#call" do
    let(:aggregation_result) do
      BaseService::Result.new.tap do |result|
        result.aggregation = 9
        result.count = 4
        result.options = {}
      end
    end

    let(:charge_result) do
      BaseService::Result.new.tap do |result|
        result.amount = 10
        result.precise_amount = 10.0
        result.unit_amount = 0.01111111111
        result.count = 1
        result.units = 9
      end
    end

    before do
      allow(Charges::PayInAdvanceAggregationService).to receive(:call)
        .with(charge:, boundaries: BillingPeriodBoundaries, properties: Hash, event:, charge_filter:)
        .and_return(aggregation_result)

      allow(Charges::ApplyPayInAdvanceChargeModelService).to receive(:call)
        .with(charge:, aggregation_result:, properties: Hash)
        .and_return(charge_result)
    end

    it "creates a fee" do
      result = fee_service.call

      expect(result).to be_success

      expect(result.fees.count).to eq(1)
      expect(result.fees.first).to have_attributes(
        subscription:,
        organization_id: organization.id,
        billing_entity_id: billing_entity.id,
        charge:,
        amount_cents: 10,
        precise_amount_cents: 10.0,
        amount_currency: "EUR",
        fee_type: "charge",
        pay_in_advance: true,
        invoiceable: charge,
        units: 9,
        properties: Hash,
        events_count: 1,
        charge_filter: nil,
        pay_in_advance_event_id: event.id,
        pay_in_advance_event_transaction_id: event.transaction_id,
        payment_status: "pending",
        unit_amount_cents: 1,
        precise_unit_amount: 0.01111111111,

        taxes_rate: 0,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.0
      )
      expect(result.fees.first.applied_taxes.count).to eq(0)
    end

    it "does not create pricing unit usage" do
      expect { fee_service.call }.not_to change(PricingUnitUsage, :count)
    end

    it "delivers a webhook" do
      fee_service.call

      expect(SendWebhookJob).to have_been_enqueued
        .with("fee.created", Fee)
    end

    context "when aggregation fails" do
      let(:aggregation_result) do
        BaseService::Result.new.service_failure!(code: "failure", message: "Failure")
      end

      it "returns a failure" do
        result = fee_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("failure")
        expect(result.error.error_message).to eq("Failure")
      end
    end

    context "when charge model fails" do
      let(:charge_result) do
        BaseService::Result.new.service_failure!(code: "failure", message: "Failure")
      end

      it "returns a failure" do
        result = fee_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("failure")
        expect(result.error.error_message).to eq("Failure")
      end
    end

    context "when charge has a charge filter" do
      let(:event_properties) do
        {
          payment_method: "card",
          card_location: "domestic",
          scheme: "visa",
          card_type: "credit"
        }
      end

      let(:card_location) do
        create(:billable_metric_filter, billable_metric:, key: "card_location", values: %i[domestic])
      end
      let(:scheme) { create(:billable_metric_filter, billable_metric:, key: "scheme", values: %i[visa mastercard]) }

      let(:filter) { create(:charge_filter, charge:) }
      let(:filter_values) do
        [
          create(
            :charge_filter_value,
            values: ["domestic"],
            billable_metric_filter: card_location,
            charge_filter: filter
          ),
          create(
            :charge_filter_value,
            values: %w[visa mastercard],
            billable_metric_filter: scheme,
            charge_filter: filter
          )
        ]
      end

      let(:charge_filter) { filter }

      before { filter_values }

      it "creates a fee" do
        result = fee_service.call

        expect(result).to be_success

        expect(result.fees.count).to eq(1)
        expect(result.fees.first).to have_attributes(
          subscription:,
          charge:,
          amount_cents: 10,
          precise_amount_cents: 10.0,
          amount_currency: "EUR",
          fee_type: "charge",
          pay_in_advance: true,
          invoiceable: charge,
          units: 9,
          properties: Hash,
          events_count: 1,
          charge_filter:,
          pay_in_advance_event_id: event.id,
          pay_in_advance_event_transaction_id: event.transaction_id,
          unit_amount_cents: 1,
          precise_unit_amount: 0.01111111111,

          taxes_rate: 0,
          taxes_amount_cents: 0,
          taxes_precise_amount_cents: 0.0
        )
        expect(result.fees.first.applied_taxes.count).to eq(0)
      end

      context "when charge filter has pricing_group_keys defined" do
        let(:charge_filter) { create(:charge_filter, charge:, properties: {:amount => "1", "pricing_group_keys" => ["group_key"]}) }
        let(:event_properties) do
          {
            payment_method: "card",
            card_location: "international",
            scheme: "visa",
            card_type: "credit",
            group_key: "group_value"
          }
        end

        it "creates a fee" do
          result = fee_service.call

          expect(result).to be_success

          expect(result.fees.count).to eq(1)
          expect(result.fees.first).to have_attributes(
            subscription:,
            charge:,
            amount_cents: 10,
            precise_amount_cents: 10.0,
            amount_currency: "EUR",
            fee_type: "charge",
            pay_in_advance: true,
            invoiceable: charge,
            units: 9,
            properties: Hash,
            events_count: 1,
            charge_filter:,
            pay_in_advance_event_id: event.id,
            pay_in_advance_event_transaction_id: event.transaction_id,
            unit_amount_cents: 1,
            precise_unit_amount: 0.01111111111,
            grouped_by: {"group_key" => "group_value"},

            taxes_rate: 0,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0.0
          )
          expect(result.fees.first.applied_taxes.count).to eq(0)
        end
      end

      context "when charge filter has a grouped_by defined" do
        let(:charge_filter) { create(:charge_filter, charge:, properties: {:amount => "1", "grouped_by" => ["group_key"]}) }
        let(:event_properties) do
          {
            payment_method: "card",
            card_location: "international",
            scheme: "visa",
            card_type: "credit",
            group_key: "group_value"
          }
        end

        it "creates a fee" do
          result = fee_service.call

          expect(result).to be_success

          expect(result.fees.count).to eq(1)
          expect(result.fees.first).to have_attributes(
            subscription:,
            charge:,
            amount_cents: 10,
            precise_amount_cents: 10.0,
            amount_currency: "EUR",
            fee_type: "charge",
            pay_in_advance: true,
            invoiceable: charge,
            units: 9,
            properties: Hash,
            events_count: 1,
            charge_filter:,
            pay_in_advance_event_id: event.id,
            pay_in_advance_event_transaction_id: event.transaction_id,
            unit_amount_cents: 1,
            precise_unit_amount: 0.01111111111,
            grouped_by: {"group_key" => "group_value"},

            taxes_rate: 0,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0.0
          )
          expect(result.fees.first.applied_taxes.count).to eq(0)
        end
      end

      context "when event does not match the charge filter" do
        let(:charge_filter) { ChargeFilter }

        let(:event_properties) do
          {
            payment_method: "card",
            card_location: "international",
            scheme: "visa",
            card_type: "credit"
          }
        end

        it "creates a fee" do
          result = fee_service.call

          expect(result).to be_success

          expect(result.fees.count).to eq(1)
          expect(result.fees.first).to have_attributes(
            subscription:,
            charge:,
            amount_cents: 10,
            precise_amount_cents: 10.0,
            amount_currency: "EUR",
            fee_type: "charge",
            pay_in_advance: true,
            invoiceable: charge,
            units: 9,
            properties: Hash,
            events_count: 1,
            charge_filter_id: nil,
            pay_in_advance_event_id: event.id,
            pay_in_advance_event_transaction_id: event.transaction_id,
            unit_amount_cents: 1,
            precise_unit_amount: 0.01111111111,

            taxes_rate: 0,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0.0
          )
          expect(result.fees.first.applied_taxes.count).to eq(0)
        end
      end
    end

    context "when charge has a grouped_by property" do
      let(:charge) do
        create(
          :standard_charge,
          billable_metric:,
          pay_in_advance: true,
          properties: {"grouped_by" => ["operator"], "amount" => "100"}
        )
      end

      let(:event) do
        Events::CommonFactory.new_instance(
          source: create(
            :event,
            organization:,
            external_subscription_id: subscription.external_id,
            properties: {"operator" => "foo"}
          )
        )
      end

      it "creates a fee" do
        result = fee_service.call

        expect(result).to be_success

        expect(result.fees.count).to eq(1)
        expect(result.fees.first).to have_attributes(
          subscription:,
          charge:,
          amount_cents: 10,
          precise_amount_cents: 10.0,
          amount_currency: "EUR",
          fee_type: "charge",
          pay_in_advance: true,
          invoiceable: charge,
          units: 9,
          properties: Hash,
          events_count: 1,
          pay_in_advance_event_id: event.id,
          pay_in_advance_event_transaction_id: event.transaction_id,
          unit_amount_cents: 1,
          precise_unit_amount: 0.01111111111,
          grouped_by: {"operator" => "foo"},

          taxes_rate: 0,
          taxes_amount_cents: 0,
          taxes_precise_amount_cents: 0.0
        )
        expect(result.fees.first.applied_taxes.count).to eq(0)
      end
    end

    context "when event is not persisted" do
      let(:estimate) { true }
      let(:event) do
        Events::Common.new(
          id: nil,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          organization_id: organization.id,
          properties: event_properties,
          timestamp: Time.current,
          precise_total_amount_cents: nil,
          persisted: false
        )
      end

      it "does not persist the fee and defers taxes to the caller" do
        result = fee_service.call

        expect(result).to be_success

        expect(result.fees.count).to eq(1)
        expect(result.fees.first).not_to be_persisted
        expect(result.fees.first).to have_attributes(
          subscription:,
          charge:,
          amount_cents: 10,
          precise_amount_cents: 10.0,
          amount_currency: "EUR",
          fee_type: "charge",
          pay_in_advance: true,
          invoiceable: charge,
          units: 9,
          properties: Hash,
          events_count: 1,
          pay_in_advance_event_id: event.id,
          pay_in_advance_event_transaction_id: event.transaction_id,
          unit_amount_cents: 1,
          precise_unit_amount: 0.01111111111,

          taxes_rate: 0,
          taxes_amount_cents: 0,
          taxes_precise_amount_cents: 0.0
        )
        expect(result.fees.first.applied_taxes.size).to eq(0)
      end

      it "does not deliver a webhook" do
        fee_service.call

        expect(SendWebhookJob).not_to have_been_enqueued
          .with("fee.created", Fee)
      end

      context "when stimate is false" do
        let(:estimate) { false }

        it "raises an argument error" do
          expect { fee_service.call }
            .to raise_error(ArgumentError, "estimate must be true if event if not persisted")
        end
      end
    end

    context "with pricing unit on the charge" do
      before do
        create(
          :applied_pricing_unit,
          organization: subscription.organization,
          conversion_rate: 0.5,
          pricing_unitable: charge
        )
      end

      it "creates a fee with converted values" do
        result = fee_service.call

        expect(result).to be_success

        expect(result.fees.count).to eq(1)
        fee = result.fees.first
        expect(fee).to have_attributes(
          subscription:,
          organization_id: organization.id,
          billing_entity_id: billing_entity.id,
          charge:,
          amount_cents: 5,
          amount_currency: "EUR",
          fee_type: "charge",
          pay_in_advance: true,
          invoiceable: charge,
          units: 9,
          events_count: 1,
          charge_filter: nil,
          pay_in_advance_event_id: event.id,
          pay_in_advance_event_transaction_id: event.transaction_id,
          payment_status: "pending",
          unit_amount_cents: 0,
          taxes_rate: 0,
          taxes_amount_cents: 0
        )
        expect(fee.precise_amount_cents.to_f).to eq(5.0)
        expect(fee.precise_unit_amount.to_f).to eq(0.005)
        expect(fee.taxes_precise_amount_cents.to_f).to eq(0.0)
        expect(result.fees.first.applied_taxes.count).to eq(0)
      end

      it "creates pricing unit usage" do
        result = fee_service.call

        expect(result).to be_success
        pricing_unit_usage = result.fees.first.pricing_unit_usage
        expect(pricing_unit_usage).to be_persisted
        expect(pricing_unit_usage.amount_cents).to eq(10)
        expect(pricing_unit_usage.precise_amount_cents.to_f).to eq(10.0)
        expect(pricing_unit_usage.unit_amount_cents).to eq(1)
      end
    end

    context "when in current and max aggregation result" do
      let(:aggregation_result) do
        BaseService::Result.new.tap do |result|
          result.amount = 10
          result.count = 1
          result.units = 9
          result.current_aggregation = 9
          result.max_aggregation = 9
          result.max_aggregation_with_proration = nil
        end
      end

      it "creates a cached aggregation" do
        expect { fee_service.call }.to change(CachedAggregation, :count).by(1)

        cached_aggregation = CachedAggregation.last
        expect(cached_aggregation.organization_id).to eq(organization.id)
        expect(cached_aggregation.event_transaction_id).to eq(event.transaction_id)
        expect(cached_aggregation.timestamp.iso8601(3)).to eq(event.timestamp.iso8601(3))
        expect(cached_aggregation.charge_id).to eq(charge.id)
        expect(cached_aggregation.external_subscription_id).to eq(event.external_subscription_id)
        expect(cached_aggregation.charge_filter_id).to be_nil
        expect(cached_aggregation.current_aggregation).to eq(9)
        expect(cached_aggregation.current_amount).to be_nil
        expect(cached_aggregation.max_aggregation).to eq(9)
        expect(cached_aggregation.max_aggregation_with_proration).to be_nil
        expect(cached_aggregation.grouped_by).to eq({})
        expect(cached_aggregation.presentation_breakdowns).to eq([])
      end

      context "with presentation_group_keys" do
        let(:charge) do
          create(:standard_charge, :pay_in_advance, billable_metric:, plan:,
            properties: {amount: "10", pricing_group_keys: ["cloud"], presentation_group_keys: [{"value" => "region"}]})
        end
        let(:event_properties) { {"cloud" => "aws", "region" => "us-east-1"} }
        let(:aggregation_result) do
          BaseService::Result.new.tap do |result|
            result.amount = 10
            result.count = 1
            result.units = 9
            result.current_aggregation = 9
            result.max_aggregation = 9
            result.max_aggregation_with_proration = nil
            result.breakdowns = [{groups: {"cloud" => "aws", "region" => "us-east-1"}, value: 9}]
            result.pay_in_advance_breakdowns = [{groups: {"cloud" => "aws", "region" => "us-east-1"}, value: 9}]
          end
        end

        it "stores presentation_breakdowns stripped of pricing group keys" do
          fee_service.call

          cached_aggregation = CachedAggregation.last
          expect(cached_aggregation.presentation_breakdowns.map { |b| b["groups"] }).to eq([{"region" => "us-east-1"}])
          expect(cached_aggregation.presentation_breakdowns.map { |b| b["value"] }).to eq([9])
        end

        it "builds presentation_breakdowns on the fee stripped of pricing group keys" do
          result = fee_service.call

          fee = result.fees.first
          expect(fee.presentation_breakdowns.map(&:presentation_by)).to eq([{"region" => "us-east-1"}])
          expect(fee.presentation_breakdowns.map { |b| b.units.to_i }).to eq([9])
          expect(fee.presentation_breakdowns).to all(have_attributes(organization_id: organization.id))
        end
      end

      context "with sum aggregation and presentation_group_keys" do
        let(:event) { current_event }
        let(:current_event) { first_event }
        let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "units") }
        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            billable_metric:,
            plan:,
            properties: {
              amount: "1",
              presentation_group_keys: [{"value" => "department"}, {"value" => "units"}]
            }
          )
        end
        let(:first_event) do
          Events::CommonFactory.new_instance(
            source: create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: subscription.started_at + 1.hour,
              properties: {"units" => "3", "department" => "engineering"}
            )
          )
        end
        let(:second_event) do
          Events::CommonFactory.new_instance(
            source: create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: subscription.started_at + 1.hour + 1.second,
              properties: {"units" => "10", "department" => "engineering"}
            )
          )
        end
        let(:third_event) do
          Events::CommonFactory.new_instance(
            source: create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: subscription.started_at + 1.hour + 2.seconds,
              properties: {"units" => "7", "department" => "engineering"}
            )
          )
        end
        let(:aggregation_result) { aggregation_results.fetch(event.transaction_id) }
        let(:charge_result) do
          BaseService::Result.new.tap do |result|
            result.amount = aggregation_result.pay_in_advance_breakdowns.sum { |breakdown| breakdown[:value] }
            result.precise_amount = result.amount.to_d
            result.unit_amount = 1
            result.count = aggregation_result.count
            result.units = result.amount
          end
        end
        let(:first_aggregation_result) do
          BaseService::Result.new.tap do |result|
            result.aggregation = 3
            result.count = 1
            result.options = {}
            result.current_aggregation = 3
            result.max_aggregation = 3
            result.breakdowns = [{groups: {"department" => "engineering", "units" => "3"}, value: 3}]
            result.pay_in_advance_breakdowns = [{groups: {"department" => "engineering", "units" => "3"}, value: 3}]
          end
        end
        let(:second_aggregation_result) do
          BaseService::Result.new.tap do |result|
            result.aggregation = 13
            result.count = 2
            result.options = {}
            result.current_aggregation = 13
            result.max_aggregation = 13
            result.breakdowns = [
              {groups: {"department" => "engineering", "units" => "3"}, value: 3},
              {groups: {"department" => "engineering", "units" => "10"}, value: 10}
            ]
            result.pay_in_advance_breakdowns = [{groups: {"department" => "engineering", "units" => "10"}, value: 10}]
          end
        end
        let(:third_aggregation_result) do
          BaseService::Result.new.tap do |result|
            result.aggregation = 20
            result.count = 3
            result.options = {}
            result.current_aggregation = 20
            result.max_aggregation = 20
            result.breakdowns = [
              {groups: {"department" => "engineering", "units" => "3"}, value: 3},
              {groups: {"department" => "engineering", "units" => "10"}, value: 10},
              {groups: {"department" => "engineering", "units" => "7"}, value: 7}
            ]
            result.pay_in_advance_breakdowns = [{groups: {"department" => "engineering", "units" => "7"}, value: 7}]
          end
        end
        let(:aggregation_results) do
          {
            first_event.transaction_id => first_aggregation_result,
            second_event.transaction_id => second_aggregation_result,
            third_event.transaction_id => third_aggregation_result
          }
        end

        it "builds presentation breakdowns from the first event" do
          result = fee_service.call

          fee = result.fees.first
          expect(fee.presentation_breakdowns.map(&:presentation_by)).to eq([
            {"department" => "engineering", "units" => "3"}
          ])
          expect(fee.presentation_breakdowns.map(&:units)).to eq([3])

          cached_aggregation = CachedAggregation.order(:created_at).last
          expect(cached_aggregation.presentation_breakdowns.map { |b| b["groups"] }).to eq([
            {"department" => "engineering", "units" => "3"}
          ])
          expect(cached_aggregation.presentation_breakdowns.map { |b| BigDecimal(b["value"]) }).to eq([3])
        end

        context "when the first event was already processed" do
          let(:current_event) { second_event }

          before do
            CachedAggregation.create!(
              organization_id: organization.id,
              event_transaction_id: first_event.transaction_id,
              timestamp: first_event.timestamp,
              external_subscription_id: first_event.external_subscription_id,
              charge_id: charge.id,
              current_aggregation: 3,
              max_aggregation: 3,
              grouped_by: {},
              presentation_breakdowns: [
                {groups: {"department" => "engineering", "units" => "3"}, value: 3}
              ]
            )
          end

          it "builds presentation breakdowns from the second event" do
            result = fee_service.call

            fee = result.fees.first
            expect(fee.presentation_breakdowns.map(&:presentation_by)).to eq([
              {"department" => "engineering", "units" => "10"}
            ])
            expect(fee.presentation_breakdowns.map(&:units)).to eq([10])

            cached_aggregation = CachedAggregation.order(:created_at).last
            expect(cached_aggregation.presentation_breakdowns.map { |b| {groups: b["groups"], value: BigDecimal(b["value"])} }).to match_array([
              {groups: {"department" => "engineering", "units" => "3"}, value: 3},
              {groups: {"department" => "engineering", "units" => "10"}, value: 10}
            ])
          end
        end

        context "when the first two events were already processed" do
          let(:current_event) { third_event }

          before do
            CachedAggregation.create!(
              organization_id: organization.id,
              event_transaction_id: first_event.transaction_id,
              timestamp: first_event.timestamp,
              external_subscription_id: first_event.external_subscription_id,
              charge_id: charge.id,
              current_aggregation: 3,
              max_aggregation: 3,
              grouped_by: {},
              presentation_breakdowns: [
                {groups: {"department" => "engineering", "units" => "3"}, value: 3}
              ]
            )
            CachedAggregation.create!(
              organization_id: organization.id,
              event_transaction_id: second_event.transaction_id,
              timestamp: second_event.timestamp,
              external_subscription_id: second_event.external_subscription_id,
              charge_id: charge.id,
              current_aggregation: 13,
              max_aggregation: 13,
              grouped_by: {},
              presentation_breakdowns: [
                {groups: {"department" => "engineering", "units" => "3"}, value: 3},
                {groups: {"department" => "engineering", "units" => "10"}, value: 10}
              ]
            )
          end

          it "builds presentation breakdowns from the third event" do
            result = fee_service.call

            fee = result.fees.first
            expect(fee.presentation_breakdowns.map(&:presentation_by)).to eq([
              {"department" => "engineering", "units" => "7"}
            ])
            expect(fee.presentation_breakdowns.map(&:units)).to eq([7])

            cached_aggregation = CachedAggregation.order(:created_at).last
            expect(cached_aggregation.max_aggregation).to eq(20.to_d)
            expect(cached_aggregation.presentation_breakdowns.map { |b| {groups: b["groups"], value: BigDecimal(b["value"])} }).to match_array([
              {groups: {"department" => "engineering", "units" => "3"}, value: 3},
              {groups: {"department" => "engineering", "units" => "10"}, value: 10},
              {groups: {"department" => "engineering", "units" => "7"}, value: 7}
            ])
          end
        end
      end
    end

    context "when charge is non-invoiceable" do
      let(:charge) { create(:standard_charge, :pay_in_advance, billable_metric:, plan:, invoiceable: false) }

      it "applies local taxes eagerly" do
        result = fee_service.call

        expect(result).to be_success

        fee = result.fees.first
        expect(fee.applied_taxes.count).to eq(1)
        expect(fee.taxes_rate).to eq(20.0)
        expect(fee.taxes_amount_cents).to eq(2)
      end

      context "when customer has tax provider integration" do
        let(:integration) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
        let(:response) { instance_double(Net::HTTPOK) }
        let(:lago_client) { instance_double(LagoHttpClient::Client) }
        let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
        let(:body) do
          p = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
          json = File.read(p)

          response_data = JSON.parse(json)
          response_data["succeededInvoices"].first["fees"].first["item_id"] = fee_id
          response_data["succeededInvoices"].first["fees"].first["tax_breakdown"].first["rate"] = "0.10"
          response_data["succeededInvoices"].first["fees"].first["tax_breakdown"].first["tax_amount"] = 1

          response_data.to_json
        end
        let(:fee_id) { "fee_placeholder" }

        let(:integration_collection_mapping) do
          create(
            :netsuite_collection_mapping,
            integration:,
            mapping_type: :fallback_item,
            settings: {external_id: "1", external_account_code: "11", external_name: ""}
          )
        end

        before do
          integration_collection_mapping
          integration_customer

          allow(LagoHttpClient::Client).to receive(:new)
            .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
            .and_return(lago_client)
          allow(lago_client).to receive(:post_with_response).and_return(response)
          allow(response).to receive(:body).and_return(body)
          allow_any_instance_of(Fee).to receive(:id).and_wrap_original do |m, *_args| # rubocop:disable RSpec/AnyInstance
            fee_id
          end
        end

        it "applies provider taxes instead of local taxes" do
          result = fee_service.call

          expect(result).to be_success

          fee = result.fees.first
          # Provider returns 2 tax breakdown entries (tax_exempt + exempt)
          expect(fee.applied_taxes.count).to eq(2)
          expect(fee.applied_taxes.map(&:tax_name)).to include("GST/HST")
          expect(fee.taxes_amount_cents).to eq(1)
        end
      end
    end
  end
end
