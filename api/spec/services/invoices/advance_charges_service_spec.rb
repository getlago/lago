# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::AdvanceChargesService do
  subject(:invoice_service) do
    described_class.new(initial_subscriptions: subscriptions, billing_at:)
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax_rate) { 89 }
  let(:tax) { create(:tax, organization:, rate: tax_rate) }

  describe "#call" do
    let(:subscription) do
      create(
        :subscription,
        plan:,
        customer:,
        subscription_at: started_at.to_date,
        started_at:,
        created_at: started_at
      )
    end
    let(:subscriptions) { [subscription] }

    let(:billable_metric) { create(:billable_metric, organization:, code: "new_user") }
    let(:billing_at) { Time.zone.now.beginning_of_month + 1.hour }
    let(:started_at) { Time.zone.now - 2.years }

    let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }

    let(:reference) { "Charges paid in advance" }

    def fee_boundaries
      prev_month = billing_at - 1.month
      charges_from_datetime = prev_month.beginning_of_month
      charges_to_datetime = prev_month.end_of_month

      {
        timestamp: rand(charges_from_datetime..charges_to_datetime),
        charges_from_datetime:,
        charges_to_datetime:
      }
    end

    before do
      allow(Invoices::Payments::CreateService).to receive(:call_async)
      allow(Invoices::TransitionToFinalStatusService).to receive(:call).and_call_original
    end

    context "with existing standalone fees" do
      before do
        tax
        charge = create(:standard_charge, :regroup_paid_fees, plan: subscription.plan)
        succeeded_fees = create_list(
          :charge_fee,
          3,
          organization_id: organization.id,
          payment_status: :succeeded,
          succeeded_at: billing_at - 1.month,
          invoice_id: nil,
          subscription:,
          charge:,
          amount_cents: 61,
          taxes_amount_cents: 16,
          properties: fee_boundaries
        )
        create_list(:charge_fee, 2, :failed, invoice_id: nil, subscription:, charge:, amount_cents: 100, properties: fee_boundaries)

        create(
          :charge_fee,
          payment_status: :succeeded,
          succeeded_at: (billing_at - 1.month).end_of_month + 1.day,
          invoice_id: nil,
          subscription:,
          charge:,
          properties: {
            timestamp: (billing_at - 1.month).end_of_month + 1.day # ??
          }
        )

        succeeded_fees.each { |fee| Fees::ApplyTaxesService.call(fee:) }
      end

      it "creates invoices" do
        result = invoice_service.call
        expect(result).to be_success

        expect(result.invoice.fees.count).to eq 3

        expect(result.invoice.total_amount_cents).to eq(61 * 3 + 16 * 3)
        expect(result.invoice.taxes_amount_cents).to eq(16 * 3) # Sum of taxes in each paid fees

        expect(result.invoice).to be_finalized.and(have_attributes({
          invoice_type: "advance_charges",
          currency: "EUR",
          issuing_date: billing_at.to_date,
          skip_charges: true,
          taxes_rate: (16.0 * 100 / 61).round(2)
        }))

        expect(result.invoice.invoice_subscriptions.count).to eq(1)
        sub = result.invoice.invoice_subscriptions.first
        expect(sub.charges_to_datetime).to match_datetime fee_boundaries[:charges_to_datetime]
        expect(sub.charges_from_datetime).to match_datetime fee_boundaries[:charges_from_datetime]
        expect(sub.invoicing_reason).to eq "in_advance_charge_periodic"

        expect(SendWebhookJob).to have_been_enqueued.with("invoice.created", result.invoice)
        expect(Utils::ActivityLog).to have_produced("invoice.created").with(result.invoice)
        expect(Invoices::GenerateDocumentsJob).to have_been_enqueued.with(invoice: result.invoice, notify: false)
        expect(SegmentTrackJob).to have_been_enqueued.once
        expect(Invoices::TransitionToFinalStatusService).to have_received(:call).with(invoice: result.invoice)

        expect(Payments::ManualCreateJob)
          .to have_been_enqueued.once
          .with(
            organization:,
            params: {
              invoice_id: result.invoice.id,
              amount_cents: result.invoice.total_amount_cents,
              reference:,
              created_at: result.invoice.created_at
            }
          )
      end

      context "with billing entity resolution" do
        it "stamps the customer's billing_entity when subscription has none" do
          invoice = invoice_service.call.invoice

          expect(invoice.billing_entity).to eq(customer.billing_entity)
        end

        context "when subscription has its own billing_entity" do
          let(:other_billing_entity) { create(:billing_entity, organization:) }

          before { subscription.update!(billing_entity: other_billing_entity) }

          it "stamps the subscription's billing_entity on the invoice" do
            invoice = invoice_service.call.invoice

            expect(invoice.billing_entity).to eq(other_billing_entity)
          end
        end
      end
    end

    context "without any standalone fees" do
      context "without any pay in advance charge" do
        it "does not create an invoice" do
          result = invoice_service.call

          expect(result).to be_success
          expect(result.invoice).to be_nil
        end
      end

      context "when there is a pay in advance charge" do
        before do
          create(:standard_charge, :regroup_paid_fees, plan: subscription.plan)
        end

        it "does not try to create an invoice only to roll back when there are no fees" do
          connection = ActiveRecord::Base.connection
          allow(connection).to receive(:transaction).and_call_original

          result = invoice_service.call
          expect(connection).not_to have_received(:transaction)

          expect(result).to be_success
          expect(result.invoice).to be_nil
        end
      end
    end

    context "when there is a successful non invoiceable paid in advance fees" do
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:) }

      let(:charge) do
        create(
          :charge,
          plan:,
          billable_metric:,
          prorated: true,
          pay_in_advance: true,
          invoiceable: false,
          regroup_paid_fees: "invoice",
          properties: {amount: "1"}
        )
      end

      let(:subscription_2) do
        create(:subscription, {
          external_id: subscription.external_id,
          customer: subscription.customer,
          status: :terminated,
          terminated_at: Time.current,
          started_at: Time.current - 1.year,
          plan:
        })
      end

      let(:paid_in_advance_fee) do
        create(
          :fee,
          :succeeded,
          organization_id: organization.id,
          succeeded_at: fee_boundaries[:charges_to_datetime] - 2.days,
          invoice_id: nil,
          subscription: subscription_2,
          amount_cents: 999,
          taxes_amount_cents: 24,
          properties: fee_boundaries,
          charge:
        )
      end

      before { paid_in_advance_fee }

      it "creates invoices" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice).to be_a Invoice
        expect(result.invoice.fees.count).to eq 1
        expect(result.invoice.total_amount_cents).to eq(999 + 24)
        expect(result.invoice.taxes_amount_cents).to eq 24
        expect(result.invoice.fees_amount_cents).to eq 999

        expect(result.invoice)
          .to be_finalized
          .and have_attributes(
            invoice_type: "advance_charges",
            currency: "EUR",
            issuing_date: billing_at.to_date,
            skip_charges: true
          )

        expect(result.invoice.invoice_subscriptions.count).to eq(1)
        sub = result.invoice.invoice_subscriptions.first
        expect(sub.charges_to_datetime).to match_datetime fee_boundaries[:charges_to_datetime]
        expect(sub.charges_from_datetime).to match_datetime fee_boundaries[:charges_from_datetime]
        expect(sub.invoicing_reason).to eq "in_advance_charge_periodic"
      end
    end

    context "with integration requiring sync" do
      before do
        tax
        charge = create(:standard_charge, :regroup_paid_fees, plan: subscription.plan)
        create(
          :charge_fee,
          organization_id: organization.id,
          payment_status: :succeeded,
          succeeded_at: billing_at - 1.month,
          invoice_id: nil,
          subscription:,
          charge:,
          amount_cents: 100,
          properties: fee_boundaries
        )

        allow_any_instance_of(Invoice).to receive(:should_sync_invoice?).and_return(true) # rubocop:disable RSpec/AnyInstance
      end

      it "creates invoices" do
        result = invoice_service.call

        expect(Integrations::Aggregator::Invoices::CreateJob).to have_been_enqueued.with(invoice: result.invoice)
      end
    end
  end
end
