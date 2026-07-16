# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::InitFromAdjustedChargeFeeService do
  subject(:init_service) { described_class.new(adjusted_fee:, boundaries:, properties:) }

  let(:subscription) do
    create(
      :subscription,
      status: :active,
      started_at: DateTime.parse("2022-03-15")
    )
  end
  let(:organization) { invoice.organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:invoice) { create(:invoice, status: :draft) }
  let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

  let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
  let(:charge) do
    create(
      :standard_charge,
      plan: subscription.plan,
      billable_metric:,
      properties: {
        amount: "23.45",
        amount_currency: "EUR"
      }
    )
  end
  let(:properties) { charge.properties }

  let(:boundaries) do
    {
      charges_from_datetime: subscription.started_at.beginning_of_day,
      charges_to_datetime: subscription.started_at.end_of_month.end_of_day
    }
  end

  let(:adjusted_fee) do
    create(
      :adjusted_fee,
      invoice:,
      subscription:,
      charge:,
      properties: {},
      fee_type: :charge,
      adjusted_units: true,
      adjusted_amount: false,
      units: 7
    )
  end

  before do
    invoice_subscription
  end

  context "with adjusted units" do
    context "when adjusted fee's charge has pricing unit associated" do
      before do
        create(
          :applied_pricing_unit,
          pricing_unitable: charge,
          pricing_unit: create(:pricing_unit, organization:),
          conversion_rate: 10
        )
      end

      it "initializes a fee" do
        result = init_service.call

        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          id: nil,
          organization_id: organization.id,
          billing_entity_id: billing_entity.id,
          invoice:,
          subscription:,
          charge:,
          amount_cents: 164150,
          precise_amount_cents: 164150,
          taxes_precise_amount_cents: 0.0,
          amount_currency: invoice.currency,
          units: 7,
          unit_amount_cents: 23450,
          precise_unit_amount: 234.5,
          events_count: 0,
          payment_status: "pending",
          pricing_unit_usage: PricingUnitUsage
        )

        expect(result.fee.pricing_unit_usage).to have_attributes(
          amount_cents: 16415,
          precise_amount_cents: 16415,
          unit_amount_cents: 2345,
          precise_unit_amount: 23.45,
          conversion_rate: 10
        )
      end
    end

    context "when adjusted fee's charge has no pricing unit associated" do
      it "initializes a fee" do
        result = init_service.call

        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          id: nil,
          organization_id: organization.id,
          billing_entity_id: billing_entity.id,
          invoice:,
          subscription:,
          charge:,
          amount_cents: 16415,
          precise_amount_cents: 16415,
          taxes_precise_amount_cents: 0.0,
          amount_currency: invoice.currency,
          units: 7,
          unit_amount_cents: 2345,
          precise_unit_amount: 23.45,
          events_count: 0,
          payment_status: "pending",
          pricing_unit_usage: nil
        )
      end
    end
  end

  context "with adjusted amount" do
    let(:adjusted_fee) do
      create(
        :adjusted_fee,
        invoice:,
        subscription:,
        charge:,
        properties:,
        fee_type: :charge,
        adjusted_units: false,
        adjusted_amount: true,
        units: 4,
        unit_amount_cents: 200,
        unit_precise_amount_cents: 200.0
      )
    end

    context "when adjusted fee's charge has pricing unit associated" do
      before do
        create(
          :applied_pricing_unit,
          pricing_unitable: charge,
          pricing_unit: create(:pricing_unit, organization:),
          conversion_rate: 0.5
        )
      end

      it "initializes a fee" do
        result = init_service.call

        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          id: nil,
          invoice:,
          charge:,
          amount_cents: 400,
          precise_amount_cents: 400.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: invoice.currency,
          units: 4,
          unit_amount_cents: 100,
          precise_unit_amount: 1,
          events_count: 0,
          payment_status: "pending",
          pricing_unit_usage: PricingUnitUsage
        )

        expect(result.fee.pricing_unit_usage).to have_attributes(
          amount_cents: 800,
          precise_amount_cents: 800.0,
          unit_amount_cents: 200,
          precise_unit_amount: 2.00,
          conversion_rate: 0.5
        )
      end
    end

    context "when adjusted fee's charge has no pricing unit associated" do
      it "initializes a fee" do
        result = init_service.call

        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          id: nil,
          invoice:,
          charge:,
          amount_cents: 800,
          precise_amount_cents: 800.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: invoice.currency,
          units: 4,
          unit_amount_cents: 200,
          precise_unit_amount: 2,
          events_count: 0,
          payment_status: "pending"
        )
      end

      context "when units are 0" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            charge:,
            properties:,
            fee_type: :charge,
            adjusted_units: false,
            adjusted_amount: true,
            units: 0,
            unit_amount_cents: 0,
            unit_precise_amount_cents: 0.0
          )
        end

        it "initializes a fee" do
          result = init_service.call

          expect(result).to be_success
          expect(result.fee).to be_a(Fee)
          expect(result.fee).to have_attributes(
            id: nil,
            invoice:,
            charge:,
            amount_cents: 0,
            precise_amount_cents: 0.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: invoice.currency,
            units: 0,
            unit_amount_cents: 0,
            precise_unit_amount: 0,
            events_count: 0,
            payment_status: "pending"
          )
        end
      end
    end
  end

  context "with charge model error" do
    let(:error_result) do
      BaseService::Result.new.tap do |result|
        result.service_failure!(code: "error", message: "message")
      end
    end

    let(:charge_model_instance) { instance_double(ChargeModels::StandardService) }

    it "returns an error" do
      allow(ChargeModels::StandardService).to receive(:new).and_return(charge_model_instance)
      allow(charge_model_instance).to receive(:apply).and_return(error_result)

      result = init_service.call
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.code).to eq("error")
      expect(result.error.error_message).to eq("message")
    end
  end
end
