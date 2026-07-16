# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::Commitments::Minimum::CalculatePreviewFeeService do
  subject(:result) do
    described_class.call(
      invoice_subscription: virtual_invoice_subscription,
      preview_fees_amount_cents:,
      preview_fees_precise_amount_cents:
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: false, amount_cents: 100_00) }
  let(:subscription) { create(:subscription, customer:, plan:, started_at: from_datetime) }
  let(:preview_invoice) { Invoice.new(organization:, customer:, billing_entity: customer.billing_entity, invoice_type: :subscription, currency: "EUR") }

  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
  let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59") }
  let(:billing_time) { DateTime.parse("2025-01-01T10:00:00") }

  let(:virtual_invoice_subscription) do
    InvoiceSubscription.new(
      subscription:,
      invoice: preview_invoice,
      organization_id: organization.id,
      from_datetime:,
      to_datetime:,
      timestamp: billing_time
    )
  end

  let(:preview_fees_amount_cents) { 0 }
  let(:preview_fees_precise_amount_cents) { 0.0 }

  context "when plan has no minimum commitment" do
    it "returns no fee" do
      expect(result).to be_success
      expect(result.fee).to be_nil
    end
  end

  context "when plan has a minimum commitment" do
    let!(:commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_00) }

    context "when plan is pay-in-advance" do
      let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 100_00) }

      context "when no previous invoice subscription exists (first period)" do
        it "returns no fee (nothing to reconcile yet)" do
          expect(result).to be_success
          expect(result.fee).to be_nil
        end
      end

      context "when a previous period exists to reconcile" do
        let(:prev_to_datetime) { DateTime.parse("2024-12-31T23:59:59") }
        let(:prev_invoice) { create(:invoice, customer:, organization:) }

        # current advance billing period (2025)
        let(:virtual_invoice_subscription) do
          InvoiceSubscription.new(
            subscription:,
            invoice: preview_invoice,
            organization_id: organization.id,
            from_datetime: DateTime.parse("2025-01-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59"),
            timestamp: DateTime.parse("2025-01-01T10:00:00")
          )
        end

        let(:current_invoice) { create(:invoice, customer:, organization:) }
        let(:charge) { create(:standard_charge, plan:) }

        before do
          create(
            :invoice_subscription,
            subscription:,
            invoice: prev_invoice,
            from_datetime:,
            to_datetime: prev_to_datetime,
            timestamp: DateTime.parse("2024-01-01T10:00:00")
          )
          # previous_invoice_subscription method filters invoice subscriptions using find(&:subscription_fee),
          # so the invoice subscription won't be found for reconciliation unless a subscription fee exists on it.
          create(:fee, fee_type: :subscription, subscription:, invoice: prev_invoice, amount_cents: 0)
          create(
            :charge_fee,
            subscription:,
            invoice: current_invoice,
            charge:,
            amount_cents: 800_00,
            precise_amount_cents: 800_00.0,
            properties: {
              "charges_from_datetime" => "2025-01-01T00:00:00Z",
              "charges_to_datetime" => "2025-12-31T23:59:59Z"
            }
          )
        end

        it "stores the previous period boundaries, not the current advance period" do
          fee = result.fee
          expect(Time.zone.parse(fee.properties["from_datetime"].to_s).to_date).to eq(from_datetime.to_date)
          expect(Time.zone.parse(fee.properties["to_datetime"].to_s).to_date).to eq(prev_to_datetime.to_date)
        end

        context "when historical fees exist in the previous period" do
          let(:charge) { create(:standard_charge, plan:) }

          before do
            create(
              :charge_fee,
              subscription:,
              invoice: prev_invoice,
              charge:,
              amount_cents: 600_00,
              precise_amount_cents: 600_00.0,
              properties: {
                "charges_from_datetime" => from_datetime.iso8601,
                "charges_to_datetime" => prev_to_datetime.iso8601
              }
            )
          end

          it "deducts previous period fees from the commitment" do
            # commitment = 1_000_00, previous_period_fees = 600_00, preview_fees = 0
            # true-up = 1_000_00 - 600_00 = 400_00
            expect(result).to be_success
            expect(result.fee.amount_cents).to eq(400_00)
          end
        end
      end

      context "when subscription is terminated mid advance period" do
        let(:advance_year_start) { DateTime.parse("2026-01-01T00:00:00") }
        let(:terminated_at) { DateTime.parse("2026-07-01T00:00:00") }
        let(:subscription) do
          create(
            :subscription,
            customer:,
            plan:,
            started_at: advance_year_start,
            status: :terminated,
            terminated_at:
          )
        end
        let(:prev_invoice) { create(:invoice, customer:, organization:) }
        let(:virtual_invoice_subscription) do
          InvoiceSubscription.new(
            subscription:,
            invoice: preview_invoice,
            organization_id: organization.id,
            from_datetime: advance_year_start,
            to_datetime: DateTime.parse("2026-12-31T23:59:59"),
            timestamp: terminated_at
          )
        end

        before do
          create(
            :invoice_subscription,
            subscription:,
            invoice: prev_invoice,
            from_datetime: advance_year_start,
            to_datetime: DateTime.parse("2026-12-31T23:59:59"),
            timestamp: DateTime.parse("2026-01-01T10:00:00")
          )
          # We need a previous invoice subscription fee to exist
          create(:fee, fee_type: :subscription, subscription:, invoice: prev_invoice, amount_cents: 0)
        end

        it "prorates commitment using terminated_at, not the advance IS to_datetime" do
          fee = result.fee
          expect(fee).not_to be_nil
          # days_active = 182 (Jan 1 => Jul 1), days_total = 365 (Jan 1 => Dec 31)
          # proration = 182 / 365.0 = 0.4986... => (100_000 * 0.4986...).round = 49_863
          # Without terminated_at: days_active = 365, proration = 1.0 => commitment = 1_000_00
          expect(fee.amount_cents).to eq(49_863)
        end
      end
    end

    context "when preview fees already meet the commitment" do
      let(:preview_fees_amount_cents) { 1_000_00 }
      let(:preview_fees_precise_amount_cents) { 1_000_00.0 }

      it "returns no fee" do
        expect(result).to be_success
        expect(result.fee).to be_nil
      end
    end

    context "when preview fees are below the commitment" do
      let(:preview_fees_amount_cents) { 800_00 }
      let(:preview_fees_precise_amount_cents) { 800_00.0 }

      it "returns a commitment fee for the difference" do
        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        expect(result.fee).to have_attributes(
          fee_type: "commitment",
          invoiceable_type: "Commitment",
          invoiceable_id: commitment.id,
          amount_cents: 200_00,
          units: 1,
          taxes_amount_cents: 0,
          subscription: subscription,
          invoice: preview_invoice
        )
      end

      it "stores commitment period boundaries in properties" do
        fee = result.fee
        expect(Time.zone.parse(fee.properties["from_datetime"].to_s).to_date).to eq(from_datetime.to_date)
        expect(Time.zone.parse(fee.properties["to_datetime"].to_s).to_date).to eq(to_datetime.to_date)
      end
    end

    context "when historical DB fees exist for the commitment period" do
      let(:preview_fees_amount_cents) { 100_00 }
      let(:preview_fees_precise_amount_cents) { 100_00.0 }

      let(:past_invoice) { create(:invoice, customer:, organization:) }
      let(:past_invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoice: past_invoice,
          from_datetime:,
          to_datetime: DateTime.parse("2024-06-30T23:59:59"),
          timestamp: DateTime.parse("2024-07-01T00:00:00")
        )
      end
      let(:charge) { create(:standard_charge, plan:) }

      before do
        past_invoice_subscription

        create(
          :charge_fee,
          subscription:,
          invoice: past_invoice,
          charge:,
          amount_cents: 700_00,
          precise_amount_cents: 700_00.0,
          properties: {
            "charges_from_datetime" => from_datetime.iso8601,
            "charges_to_datetime" => DateTime.parse("2024-06-30T23:59:59").iso8601
          }
        )
      end

      it "includes historical DB fees in the total and reduces the true-up" do
        # commitment = 100_000 cents
        # db_fees = 700_00, preview_fees = 100_00, total = 800_00
        # true-up = 100_000 - 80_000 = 20_000
        expect(result).to be_success
        expect(result.fee.amount_cents).to eq(200_00)
      end

      context "when DB fees + preview fees cover the commitment" do
        let(:preview_fees_amount_cents) { 400_00 }
        let(:preview_fees_precise_amount_cents) { 400_00.0 }

        it "returns no fee" do
          # db_fees = 700_00, preview_fees = 400_00, total = 1_100_00 >= 1_000_00
          expect(result).to be_success
          expect(result.fee).to be_nil
        end
      end
    end

    context "when subscription started mid-period (prorated commitment)" do
      let(:from_datetime) { DateTime.parse("2024-07-01T00:00:00") }
      let(:subscription) { create(:subscription, customer:, plan:, started_at: from_datetime) }
      let(:preview_fees_amount_cents) { 0 }
      let(:preview_fees_precise_amount_cents) { 0.0 }

      it "prorates the commitment amount" do
        fee = result.fee
        expect(fee).not_to be_nil
        # days_active = 184 (Jul 1 => Dec 31 2024)
        # days_total  = 366 (Jul 1 2023 => Jun 30 2024)
        # proration = 184 / 366.0 => (100_000 * 0.5027...).round = 50_273
        expect(fee.amount_cents).to eq(50_273)
      end
    end

    context "when subscription is not persisted" do
      let(:subscription) { build(:subscription, customer:, plan:, started_at: from_datetime) }

      it "returns a commitment fee using virtual IS dates with no historical fees" do
        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.fee).not_to be_persisted
        # Full commitment (no proration, started Jan 1) minus zero preview/historical fees
        expect(result.fee.amount_cents).to eq(1_000_00)
      end

      context "when preview fees are below the commitment" do
        let(:preview_fees_amount_cents) { 300_00 }
        let(:preview_fees_precise_amount_cents) { 300_00.0 }

        it "uses preview fees as the only offset (no DB history possible)" do
          expect(result).to be_success
          expect(result.fee.amount_cents).to eq(700_00)
        end
      end
    end
  end
end
