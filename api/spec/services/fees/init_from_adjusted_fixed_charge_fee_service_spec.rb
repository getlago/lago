# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::InitFromAdjustedFixedChargeFeeService do
  subject(:result) { described_class.call(adjusted_fee:, boundaries:, properties:) }

  let(:subscription) do
    create(
      :subscription,
      status: :active,
      started_at: Time.zone.parse("2022-03-15")
    )
  end

  let(:organization) { invoice.organization }
  let(:billing_entity) { organization.default_billing_entity }

  let(:invoice) { create(:invoice, :draft) }

  let(:fixed_charge) do
    create(
      "fixed_charge",
      plan: subscription.plan,
      charge_model: "standard",
      properties: {
        amount: "20"
      }
    )
  end

  let(:fixed_charge_fee) do
    create(:fixed_charge_fee, invoice:, subscription:, fixed_charge:)
  end

  let(:boundaries) do
    {
      fixed_charges_from_datetime: subscription.started_at.beginning_of_day,
      fixed_charges_to_datetime: subscription.started_at.end_of_month.end_of_day
    }
  end

  let(:properties) { fixed_charge.properties }

  context "with adjusted units" do
    let(:adjusted_fee) do
      create(
        :adjusted_fee,
        fee: fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        properties: {},
        fee_type: "fixed_charge",
        adjusted_units: true,
        adjusted_amount: false,
        units: 5
      )
    end

    it "initializes a fixed charge fee with adjusted units" do
      expect(result).to be_success
      expect(result.fee).to be_a(Fee)
      expect(result.fee).to have_attributes(
        id: nil,
        organization:,
        billing_entity:,
        invoice:,
        subscription:,
        fixed_charge:,
        invoiceable: fixed_charge,
        fee_type: "fixed_charge",
        amount_cents: 10_000,
        precise_amount_cents: 10_000.0,
        precise_unit_amount: 20,
        unit_amount_cents: 2_000,
        taxes_precise_amount_cents: 0.0,
        amount_currency: "EUR",
        units: 5,
        events_count: 0,
        payment_status: "pending",
        pricing_unit_usage: nil,
        amount_details: be_a(Hash)
      )
    end

    context "when fixed charge is prorated" do
      let(:fixed_charge) do
        create(
          "fixed_charge",
          plan: subscription.plan,
          charge_model: "standard",
          prorated: true,
          properties: {amount: "20"}
        )
      end

      it "skips proration and initializes a fixed charge fee with adjusted units" do
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          id: nil,
          organization:,
          billing_entity:,
          invoice:,
          subscription:,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          amount_cents: 10_000,
          precise_amount_cents: 10_000.0,
          precise_unit_amount: 20,
          unit_amount_cents: 2_000,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 5,
          events_count: 0,
          payment_status: "pending",
          pricing_unit_usage: nil,
          amount_details: be_a(Hash)
        )
      end
    end
  end

  context "with adjusted amount" do
    let(:adjusted_fee) do
      create(
        :adjusted_fee,
        fee: fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        properties:,
        fee_type: "fixed_charge",
        adjusted_units: false,
        adjusted_amount: true,
        units: 10,
        unit_amount_cents: 500,
        unit_precise_amount_cents: 500
      )
    end

    it "initializes a fixed charge fee with adjusted amount" do
      expect(result).to be_success
      expect(result.fee).to be_a(Fee)
      expect(result.fee).to have_attributes(
        id: nil,
        organization:,
        billing_entity:,
        invoice:,
        subscription:,
        fixed_charge:,
        invoiceable: fixed_charge,
        fee_type: "fixed_charge",
        amount_cents: 5_000,
        precise_amount_cents: 5_000.0,
        amount_currency: "EUR",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5,
        events_count: 0,
        payment_status: "pending"
      )
    end

    it "does not include amount_details when amount is adjusted" do
      expect(result.fee.amount_details).to eq({})
    end

    context "when units are 0" do
      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          fee: fixed_charge_fee,
          invoice:,
          subscription:,
          fixed_charge:,
          properties:,
          fee_type: "fixed_charge",
          adjusted_units: false,
          adjusted_amount: true,
          units: 0,
          unit_amount_cents: 0,
          unit_precise_amount_cents: 0.0
        )
      end

      it "initializes a fixed charge fee with zero units" do
        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          id: nil,
          organization:,
          billing_entity:,
          invoice:,
          subscription:,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          amount_cents: 0,
          precise_amount_cents: 0.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 0,
          unit_amount_cents: 0,
          precise_unit_amount: 0,
          events_count: 0,
          payment_status: "pending"
        )
      end
    end

    context "when fixed charge is prorated" do
      let(:fixed_charge) do
        create(
          "fixed_charge",
          plan: subscription.plan,
          charge_model: "standard",
          prorated: true,
          properties: {amount: "20"}
        )
      end

      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          fee: fixed_charge_fee,
          invoice:,
          subscription:,
          fixed_charge:,
          properties:,
          fee_type: "fixed_charge",
          adjusted_units: false,
          adjusted_amount: true,
          units: 10,
          unit_amount_cents: 350,
          unit_precise_amount_cents: 350.0
        )
      end

      it "calculates amounts using the adjusted unit price" do
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          id: nil,
          organization:,
          billing_entity:,
          invoice:,
          subscription:,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          amount_cents: 3_500,
          precise_amount_cents: 3_500.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 10,
          unit_amount_cents: 350,
          precise_unit_amount: 3.5,
          events_count: 0,
          payment_status: "pending"
        )
      end
    end
  end

  context "with adjusted display name" do
    let(:adjusted_fee) do
      create(
        :adjusted_fee,
        fee: fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        properties:,
        fee_type: "fixed_charge",
        adjusted_units: false,
        adjusted_amount: false,
        invoice_display_name: "Custom Fixed Charge Name",
        units: 5
      )
    end

    it "initializes a fixed charge fee with adjusted display name" do
      expect(result).to be_success
      expect(result.fee).to be_a(Fee)
      expect(result.fee).to have_attributes(
        id: nil,
        organization:,
        billing_entity:,
        invoice:,
        subscription:,
        fixed_charge:,
        invoiceable: fixed_charge,
        fee_type: "fixed_charge",
        invoice_display_name: "Custom Fixed Charge Name",
        events_count: 0,
        payment_status: "pending"
      )
    end
  end

  context "with graduated charge model" do
    let(:fixed_charge) do
      create(
        "fixed_charge",
        plan: subscription.plan,
        charge_model: "graduated",
        properties: {
          graduated_ranges: [
            {
              from_value: 0,
              to_value: 10,
              per_unit_amount: "1",
              flat_amount: "5"
            },
            {
              from_value: 11,
              to_value: nil,
              per_unit_amount: "0.5",
              flat_amount: "10"
            }
          ]
        }
      )
    end

    let(:adjusted_fee) do
      create(
        :adjusted_fee,
        fee: fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        properties:,
        fee_type: "fixed_charge",
        adjusted_units: true,
        adjusted_amount: false,
        units: 15
      )
    end

    it "initializes a fixed charge fee with graduated charge model applied to adjusted units" do
      expect(result).to be_success
      expect(result.fee).to be_a(Fee)
      expect(result.fee).to have_attributes(
        id: nil,
        invoice:,
        fixed_charge:,
        amount_cents: 2750, # 5 + (10 * 1) + 10 + (5 * 0.5) = 27.50
        precise_amount_cents: 2750.0,
        amount_currency: "EUR",
        units: 15,
        fee_type: "fixed_charge",
        payment_status: "pending"
      )
    end
  end
end
