# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::CreateTrueUpService do
  let(:create_service) { described_class.new(fee:, used_amount_cents:, used_precise_amount_cents:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, organization:, rate: 20) }
  let(:plan) { create(:plan, organization:) }

  let(:charge) { create(:standard_charge, plan:, min_amount_cents: 1000) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:fee) do
    create(
      :charge_fee,
      amount_cents: used_amount_cents,
      precise_amount_cents: used_amount_cents,
      customer:,
      charge:,
      properties: {
        "from_datetime" => DateTime.parse("2023-08-01 00:00:00"),
        "to_datetime" => DateTime.parse("2023-08-31 23:59:59"),
        "charges_from_datetime" => DateTime.parse("2023-08-01 00:00:00"),
        "charges_to_datetime" => DateTime.parse("2023-08-31 23:59:59"),
        "charges_duration" => 31
      }
    )
  end
  let(:used_amount_cents) { 700 }
  let(:used_precise_amount_cents) { 700.0 }

  before { tax }

  describe "#call" do
    subject(:result) { create_service.call }

    context "when fee is nil" do
      let(:fee) { nil }

      it "does not instantiate a true-up fee" do
        expect(result).to be_success
        expect(result.true_up_fee).to be_nil
      end
    end

    context "when min_amount_cents is lower than the fee amount_cents" do
      let(:fee) { create(:charge_fee, amount_cents: 1500, precise_amount_cents: 1500.0) }

      it "does not instantiate a true-up fee" do
        expect(result).to be_success
        expect(result.true_up_fee).to be_nil
      end
    end

    it "instantiates a true-up fee" do
      travel_to(DateTime.new(2023, 4, 1)) do
        expect(result).to be_success

        expect(result.true_up_fee).to be_new_record.and have_attributes(
          subscription: fee.subscription,
          charge: fee.charge,
          amount_currency: fee.currency,
          fee_type: "charge",
          invoiceable: fee.charge,
          properties: fee.properties,
          payment_status: "pending",
          units: 1,
          events_count: 0,
          charge_filter: nil,
          amount_cents: 300,
          precise_amount_cents: 300.0,
          taxes_amount_cents: 2,
          taxes_precise_amount_cents: 2.0000000001,
          unit_amount_cents: 300,
          precise_unit_amount: 3,
          true_up_parent_fee_id: fee.id,
          pricing_unit_usage: nil
        )
      end
    end

    context "when fee's charge uses pricing units" do
      before do
        create(
          :applied_pricing_unit,
          organization:,
          conversion_rate: 0.25,
          pricing_unitable: charge
        )
      end

      it "instantiates a true-up fee" do
        travel_to(DateTime.new(2023, 4, 1)) do
          expect(result).to be_success

          expect(result.true_up_fee).to be_new_record.and have_attributes(
            subscription: fee.subscription,
            charge: fee.charge,
            amount_currency: fee.currency,
            fee_type: "charge",
            invoiceable: fee.charge,
            properties: fee.properties,
            payment_status: "pending",
            units: 1,
            events_count: 0,
            charge_filter: nil,
            amount_cents: 75,
            precise_amount_cents: 75.0,
            taxes_amount_cents: 2,
            taxes_precise_amount_cents: 2.0000000001,
            unit_amount_cents: 75,
            precise_unit_amount: 0.75,
            true_up_parent_fee_id: fee.id
          )

          expect(result.true_up_fee.pricing_unit_usage).to be_new_record.and have_attributes(
            amount_cents: 300,
            precise_amount_cents: 300.0,
            unit_amount_cents: 300,
            precise_unit_amount: 3.00
          )
        end
      end
    end

    context "when prorated" do
      let(:used_amount_cents) { 200 }
      let(:used_precise_amount_cents) { 200.0 }

      let(:fee) do
        create(
          :charge_fee,
          amount_cents: used_amount_cents,
          precise_amount_cents: used_amount_cents,
          charge:,
          properties: {
            "from_datetime" => DateTime.parse("2022-08-01 00:00:00"),
            "to_datetime" => DateTime.parse("2022-08-15 23:59:59"),
            "charges_from_datetime" => DateTime.parse("2022-08-01 00:00:00"),
            "charges_to_datetime" => DateTime.parse("2022-08-15 23:59:59"),
            "charges_duration" => 31
          }
        )
      end

      it "instantiates a prorated true-up fee" do
        travel_to(DateTime.new(2023, 4, 1)) do
          expect(result).to be_success

          expect(result.true_up_fee).to have_attributes(
            amount_cents: 284, # (1000 / 31.0 * 15) - 200
            precise_amount_cents: 283.8709677419355
          )
        end
      end
    end

    context "with customer timezone" do
      let(:customer) { create(:customer, organization:, timezone: "Pacific/Fiji") }

      it "instantiates a true-up fee" do
        travel_to(DateTime.new(2023, 9, 1)) do
          expect(result).to be_success

          expect(result.true_up_fee).to have_attributes(
            subscription: fee.subscription,
            charge: fee.charge,
            amount_currency: fee.currency,
            fee_type: "charge",
            invoiceable: fee.charge,
            properties: fee.properties,
            payment_status: "pending",
            units: 1,
            events_count: 0,
            charge_filter: nil,
            amount_cents: 300,
            precise_amount_cents: 300.0,
            unit_amount_cents: 300,
            precise_unit_amount: 3,
            true_up_parent_fee_id: fee.id
          )
        end
      end
    end
  end
end
