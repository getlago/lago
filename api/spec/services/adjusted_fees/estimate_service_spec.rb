# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdjustedFees::EstimateService do
  subject(:result) { described_class.call(invoice:, params:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }

  let(:invoice) do
    create(
      :invoice,
      :voided,
      :with_subscriptions,
      organization:,
      customer:,
      subscriptions: [subscription],
      currency: "EUR"
    )
  end

  let(:subscription) do
    create(
      :subscription,
      plan:,
      subscription_at: started_at,
      started_at:,
      created_at: started_at
    )
  end

  let(:timestamp) { Time.zone.now - 1.year }
  let(:started_at) { Time.zone.now - 2.years }
  let(:plan) { create(:plan, organization:, interval: "monthly") }
  let(:fee_subscription) do
    create(
      :fee,
      invoice: invoice,
      subscription:,
      fee_type: :subscription,
      precise_unit_amount: 20.00,
      units: 10
    )
  end

  before do
    fee_subscription
  end

  context "when fee does not exist" do
    let(:params) do
      {
        invoice_subscription_id: subscription.id,
        fee_id: "invalid_id",
        units: 5
      }
    end

    it "returns not found error" do
      expect(result).to be_failure
      expect(result.error).to be_a(BaseService::NotFoundFailure)
      expect(result.error.message).to eq("fee_not_found")
    end
  end

  context "when adjusting subscription fees" do
    context "when adjusting invoice display name" do
      let(:params) do
        {
          fee_id: fee_subscription.id,
          subscription_id: fee_subscription.subscription_id,
          invoice_display_name: "new-dis-name"
        }
      end

      it "returns adjusted fee in the result" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee.invoice_display_name).to eq "new-dis-name"
        expect(result.fee.units).to eq 10
        expect(result.fee.precise_unit_amount).to eq 20.00
      end
    end

    context "when adjusting units" do
      let(:params) do
        {
          fee_id: fee_subscription.id,
          subscription_id: fee_subscription.subscription_id,
          units: 5,
          invoice_display_name: "new-dis-name"
        }
      end

      it "returns adjusted fee in the result" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee.invoice_display_name).to eq "new-dis-name"
        expect(result.fee.units).to eq 5
      end
    end

    context "when adjusting units and unit amount" do
      let(:params) do
        {
          fee_id: fee_subscription.id,
          subscription_id: fee_subscription.subscription_id,
          units: 15,
          unit_precise_amount: 12.002,
          invoice_display_name: "new-dis-name"
        }
      end

      it "returns adjusted fee in the result" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).to have_attributes(
          units: 15.0,
          unit_amount_cents: 1200,
          precise_unit_amount: 12.002,
          invoice_display_name: "new-dis-name"
        )
      end
    end

    context "with presentation_breakdowns" do
      before do
        create(:presentation_breakdown, fee: fee_subscription, presentation_by: {"department" => "eng"}, units: 6)
        create(:presentation_breakdown, fee: fee_subscription, presentation_by: {"department" => "sales"}, units: 4)
        fee_subscription.reload
      end

      context "when adjusting units" do
        let(:params) do
          {
            fee_id: fee_subscription.id,
            subscription_id: fee_subscription.subscription_id,
            units: 5
          }
        end

        it "returns the fee without presentation_breakdowns" do
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end

      context "when keeping units the same" do
        let(:params) do
          {
            fee_id: fee_subscription.id,
            subscription_id: fee_subscription.subscription_id,
            units: 10
          }
        end

        it "returns the fee without presentation_breakdowns" do
          expect(fee_subscription.units).to eq(result.fee.units)
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end
    end
  end

  context "when adjusting fixed charge fees" do
    let(:add_on) { create(:add_on, organization:) }
    let(:fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:,
        properties: {amount: "25"}
      )
    end

    let(:fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        precise_unit_amount: 25.00,
        units: 8
      )
    end

    context "when adjusting invoice display name only" do
      let(:params) do
        {
          fee_id: fixed_charge_fee.id,
          invoice_display_name: "Adjusted fixed charge",
          # Service expects to always receive units in params when adjusting fees
          units: 8
        }
      end

      it "returns adjusted fee with updated display name" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          invoice_display_name: "Adjusted fixed charge",
          units: 8.0,
          precise_unit_amount: 25.00
        )
      end
    end

    context "when adjusting units only" do
      let(:params) do
        {
          fee_id: fixed_charge_fee.id,
          units: 12,
          invoice_display_name: "Adjusted units"
        }
      end

      it "returns adjusted fee with new units" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          units: 12.0,
          invoice_display_name: "Adjusted units"
        )
      end
    end

    context "when adjusting units and unit amount" do
      let(:params) do
        {
          fee_id: fixed_charge_fee.id,
          units: 20,
          unit_precise_amount: 18.5,
          invoice_display_name: "Adjusted amount"
        }
      end

      it "returns adjusted fee with new units and amount" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          fixed_charge:,
          invoiceable: fixed_charge,
          units: 20.0,
          unit_amount_cents: 1850,
          precise_unit_amount: 18.5,
          invoice_display_name: "Adjusted amount"
        )
      end
    end

    context "when creating empty fee for fixed charge" do
      let(:params) do
        {
          invoice_subscription_id: subscription.id,
          fixed_charge_id: fixed_charge.id,
          units: 5,
          unit_precise_amount: 30.0
        }
      end

      it "returns a new fee" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: "fixed_charge",
          units: 5.0,
          unit_amount_cents: 3000,
          precise_unit_amount: 30.0
        )
      end

      it "sets fixed charge boundaries in properties" do
        invoice_subscription = invoice.invoice_subscriptions.find_by(subscription_id: subscription.id)

        expect(invoice_subscription.fixed_charges_from_datetime).to be_present
        expect(invoice_subscription.fixed_charges_to_datetime).to be_present

        expect(result.fee.properties).to eq(
          "timestamp" => invoice_subscription.timestamp.iso8601(3),
          "fixed_charges_from_datetime" => invoice_subscription.fixed_charges_from_datetime.iso8601(3),
          "fixed_charges_to_datetime" => invoice_subscription.fixed_charges_to_datetime.iso8601(3)
        )
      end
    end

    context "when fixed_charge does not exist" do
      let(:params) do
        {
          invoice_subscription_id: subscription.id,
          fixed_charge_id: "invalid_id",
          units: 5
        }
      end

      it "returns not found error" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("fixed_charge_not_found")
      end
    end

    context "with presentation_breakdowns" do
      before do
        create(:presentation_breakdown, fee: fixed_charge_fee, presentation_by: {"region" => "eu"}, units: 5)
        create(:presentation_breakdown, fee: fixed_charge_fee, presentation_by: {"region" => "us"}, units: 3)
      end

      context "when adjusting units" do
        let(:params) { {fee_id: fixed_charge_fee.id, units: 12} }

        it "returns a fee without presentation_breakdowns" do
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end

      context "when keeping units the same" do
        let(:params) { {fee_id: fixed_charge_fee.id, units: 8} }

        it "returns the fee without presentation_breakdowns" do
          expect(fixed_charge_fee.units).to eq(result.fee.units)
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end
    end
  end

  context "when adjusting charge fees" do
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:charge) { create(:standard_charge, billable_metric:, plan:) }
    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        precise_unit_amount: 15.00,
        units: 5
      )
    end

    context "when adjusting units only" do
      let(:params) do
        {
          fee_id: charge_fee.id,
          units: 8,
          invoice_display_name: "Adjusted charge"
        }
      end

      it "returns adjusted fee with new units" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          charge:,
          invoiceable: charge,
          fee_type: "charge",
          units: 8.0,
          invoice_display_name: "Adjusted charge"
        )
      end
    end

    context "when adjusting units and amount" do
      let(:params) do
        {
          fee_id: charge_fee.id,
          units: 10,
          unit_precise_amount: 20.5
        }
      end

      it "returns adjusted fee with new units and amount" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          charge:,
          invoiceable: charge,
          fee_type: "charge",
          units: 10.0,
          unit_amount_cents: 2050,
          precise_unit_amount: 20.5
        )
      end
    end

    context "when charge has invalid model for unit adjustment" do
      let(:charge) { create(:percentage_charge, plan:) }
      let(:params) do
        {
          fee_id: charge_fee.id,
          units: 10
        }
      end

      it "returns validation error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:charge]).to eq(["invalid_charge_model"])
      end
    end

    context "when charge has invalid model but adjusting amount" do
      let(:charge) { create(:percentage_charge, plan:) }
      let(:params) do
        {
          fee_id: charge_fee.id,
          units: 10,
          unit_precise_amount: 15.5
        }
      end

      it "returns success" do
        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          charge:,
          invoiceable: charge,
          fee_type: "charge",
          units: 10.0,
          unit_amount_cents: 1550,
          precise_unit_amount: 15.5
        )
      end
    end

    context "when creating empty fee for a charge" do
      let(:params) do
        {
          invoice_subscription_id: subscription.id,
          charge_id: charge.id,
          units: 5,
          unit_precise_amount: 30.0
        }
      end

      it "returns a new fee" do
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          id: String,
          charge:,
          invoiceable: charge,
          fee_type: "charge",
          units: 5.0,
          unit_amount_cents: 3000,
          precise_unit_amount: 30.0
        )
      end

      it "sets charge boundaries in properties" do
        invoice_subscription = invoice.invoice_subscriptions.find_by(subscription_id: subscription.id)

        expect(invoice_subscription.charges_from_datetime).to be_present
        expect(invoice_subscription.charges_to_datetime).to be_present

        expect(result.fee.properties).to eq(
          "timestamp" => invoice_subscription.timestamp.iso8601(3),
          "charges_from_datetime" => invoice_subscription.charges_from_datetime.iso8601(3),
          "charges_to_datetime" => invoice_subscription.charges_to_datetime.iso8601(3)
        )
      end
    end

    context "when charge does not exist" do
      let(:params) do
        {
          invoice_subscription_id: subscription.id,
          charge_id: "invalid_id",
          units: 5
        }
      end

      it "returns not found error" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("charge_not_found")
      end
    end

    context "with presentation_breakdowns" do
      let(:charge) do
        create(
          :standard_charge,
          billable_metric:,
          plan:,
          properties: {amount: "10", presentation_group_keys: [{value: "department"}]}
        )
      end
      let(:charge_fee) do
        create(:charge_fee, invoice:, subscription:, charge:, precise_unit_amount: 10.00, units: 5)
      end

      before do
        create(:presentation_breakdown, fee: charge_fee, presentation_by: {"department" => "eng"}, units: 3)
        create(:presentation_breakdown, fee: charge_fee, presentation_by: {"department" => "sales"}, units: 2)
      end

      context "when adjusting units" do
        let(:params) { {fee_id: charge_fee.id, units: 8} }

        it "returns a fee without presentation_breakdowns" do
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end

      context "when keeping units the same" do
        let(:params) { {fee_id: charge_fee.id, units: 5} }

        it "returns the fee without presentation_breakdowns" do
          expect(charge_fee.units).to eq(result.fee.units)
          expect(result.fee.presentation_breakdowns).to be_empty
        end
      end
    end
  end
end
