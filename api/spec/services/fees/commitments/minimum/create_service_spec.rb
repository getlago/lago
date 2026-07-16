# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::Commitments::Minimum::CreateService do
  subject(:service_call) { described_class.call(invoice_subscription:) }

  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      subscription:,
      invoice:,
      from_datetime:,
      to_datetime:,
      timestamp:
    )
  end
  let(:subscription) { create(:subscription, customer:, plan:, started_at: DateTime.parse("2024-01-01T00:00:00")) }
  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
  let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59") }
  let(:timestamp) { DateTime.parse("2025-01-01T10:00:00") }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: false) }
  let(:organization) { create(:organization) }

  context "when plan has no minimum commitment" do
    it "does not create a commitment fee" do
      expect { service_call }.not_to change(Fee.commitment, :count)
    end
  end

  context "when plan has a minimum commitment" do
    before { create(:commitment, :minimum_commitment, plan:) }

    context "when invoice already has a minimum commitment fee for the subscription" do
      before { create(:minimum_commitment_fee, invoice:, subscription:) }

      it "does not create a commitment fee" do
        expect { service_call }.not_to change(Fee.commitment, :count)
      end
    end

    context "when invoice already has a minimum commitment fee for different subscription" do
      before { create(:minimum_commitment_fee, invoice:) }

      it "creates a commitment fee" do
        expect { service_call }.to change(Fee.commitment, :count).by(1)
      end
    end

    # Default behavior: pay in arrears (no explicit context needed)
    describe "commitment fee creation" do
      it "creates a commitment fee" do
        expect { service_call }.to change(Fee.commitment, :count).by(1)
      end

      it "creates a fee with correct attributes" do
        result = service_call
        expect(result).to be_success

        fee = result.fee
        expect(fee).to have_attributes(
          id: String,
          organization_id: organization.id,
          billing_entity_id: customer.billing_entity_id,
          fee_type: "commitment",
          taxes_amount_cents: 0,
          precise_amount_cents: 1000.0
        )
      end

      it "stores the current billing period boundaries in properties" do
        result = service_call
        expect(result).to be_success

        fee = result.fee
        # For pay in arrears, commitment reconciles the CURRENT period
        # Boundaries should match the invoice_subscription's from/to dates
        expect(Time.zone.parse(fee.properties["from_datetime"].to_s).to_date).to eq(from_datetime.to_date)
        expect(Time.zone.parse(fee.properties["to_datetime"].to_s).to_date).to eq(to_datetime.to_date)
      end
    end

    context "when commitment has taxes" do
      let(:commitment_tax) { create(:tax, rate: 20) }

      before do
        create(:commitment_applied_tax, commitment: plan.minimum_commitment, tax: commitment_tax)
      end

      it "creates a commitment fee with zero taxes" do
        result = service_call
        expect(result).to be_success

        fee = result.fee
        expect(fee).to have_attributes(
          taxes_amount_cents: 0,
          taxes_precise_amount_cents: 0.0,
          taxes_rate: 0.0
        )
      end
    end

    context "when plan is pay in advance" do
      let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true) }

      context "when it is the first billing period (no previous invoice subscription)" do
        it "does not create a commitment fee" do
          # On the first invoice of a pay in advance plan, there's no previous period to reconcile
          expect { service_call }.not_to change(Fee.commitment, :count)
        end

        it "returns a successful result without a fee" do
          result = service_call
          expect(result).to be_success
          expect(result.fee).to be_nil
        end
      end

      context "when there is a previous billing period to reconcile" do
        let(:previous_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
        let(:previous_to_datetime) { DateTime.parse("2024-12-31T23:59:59") }
        let(:previous_invoice) { create(:invoice, customer:, organization:) }
        let(:previous_invoice_subscription) do
          create(
            :invoice_subscription,
            subscription:,
            invoice: previous_invoice,
            from_datetime: previous_from_datetime,
            to_datetime: previous_to_datetime,
            timestamp: DateTime.parse("2024-01-01T10:00:00")
          )
        end
        let(:true_up_result) do
          BaseService::Result.new.tap do |r|
            r.amount_cents = 500
            r.precise_amount_cents = 500.0
          end
        end

        before do
          previous_invoice_subscription
          # Create a subscription fee for the previous invoice so previous_invoice_subscription is found
          create(:fee, fee_type: :subscription, subscription:, invoice: previous_invoice)
        end

        it "creates a commitment fee with the PREVIOUS billing period boundaries in properties" do
          result = service_call
          expect(result).to be_success

          fee = result.fee
          # For pay in advance, commitment reconciles the PREVIOUS period
          # Boundaries should match the previous_invoice_subscription's from/to dates
          expect(Time.zone.parse(fee.properties["from_datetime"].to_s).to_date).to eq(previous_from_datetime.to_date)
          expect(Time.zone.parse(fee.properties["to_datetime"].to_s).to_date).to eq(previous_to_datetime.to_date)
        end
      end
    end
  end
end
