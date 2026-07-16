# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::PaidCreditService do
  subject(:invoice_service) do
    described_class.new(wallet_transaction:, timestamp:, invoice:)
  end

  let(:timestamp) { Time.current.to_i }

  describe "call" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { customer.billing_entity }
    let(:customer) { create(:customer, organization:, payment_provider: :stripe) }
    let(:subscription) { create(:subscription, plan:, customer:) }
    let(:plan) { create(:plan, organization:) }
    let(:wallet) { create(:wallet, customer:) }
    let(:wallet_transaction) do
      create(:wallet_transaction, wallet:, amount: "15.00", credit_amount: "15.00", invoice_requires_successful_payment:)
    end
    let(:invoice_requires_successful_payment) { false }

    let(:invoice) { nil }

    before do
      wallet_transaction
      subscription
    end

    it "creates an invoice" do
      result = invoice_service.call

      expect(result).to be_success

      expect(result.invoice).to have_attributes(
        issuing_date: Time.zone.at(timestamp).to_date,
        invoice_type: "credit",
        payment_status: "pending",
        currency: "EUR",
        fees_amount_cents: 1500,
        sub_total_excluding_taxes_amount_cents: 1500,
        taxes_amount_cents: 0,
        taxes_rate: 0,
        sub_total_including_taxes_amount_cents: 1500,
        total_amount_cents: 1500
      )

      expect(result.invoice.applied_taxes.count).to eq(0)

      expect(result.invoice).to be_finalized
    end

    it "assigns invoice to the wallet transaction" do
      expect { invoice_service.call }
        .to change(wallet_transaction, :invoice).from(nil).to(Invoice)
    end

    context "with billing entity resolution" do
      it "stamps the customer's billing_entity when wallet has none" do
        invoice = invoice_service.call.invoice

        expect(invoice.billing_entity).to eq(customer.billing_entity)
      end

      context "when wallet has its own billing_entity and transaction has no snapshot" do
        let(:other_billing_entity) { create(:billing_entity, organization:) }
        let(:wallet_transaction) do
          create(:wallet_transaction, wallet:, amount: "15.00", credit_amount: "15.00", invoice_requires_successful_payment:, billing_entity: nil)
        end

        before { wallet.update!(billing_entity: other_billing_entity) }

        it "stamps the wallet's billing_entity on the invoice" do
          invoice = invoice_service.call.invoice

          expect(invoice.billing_entity).to eq(other_billing_entity)
        end
      end
    end

    it "enqueues a SendWebhookJob" do
      expect do
        invoice_service.call
      end.to have_enqueued_job(SendWebhookJob)
    end

    it "produces an activity log" do
      invoice = invoice_service.call.invoice

      expect(Utils::ActivityLog).to have_produced("invoice.paid_credit_added").with(invoice)
    end

    it_behaves_like "syncs invoice" do
      let(:service_call) { invoice_service.call }
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { invoice_service.call }
    end

    it_behaves_like "applies invoice_custom_sections from resource" do
      let(:service_call) { invoice_service.call }
      let(:resource_with_custom_section) { wallet_transaction }
      let(:applied_section_factory) { :wallet_transaction_applied_invoice_custom_section }
      let(:resource_association_key) { :wallet_transaction }
    end

    it_behaves_like "applies invoice_custom_sections from resource" do
      let(:service_call) { invoice_service.call }
      let(:resource_with_custom_section) { wallet }
      let(:applied_section_factory) { :wallet_applied_invoice_custom_section }
      let(:resource_association_key) { :wallet }
    end

    context "when wallet_transaction has skip_invoice_custom_sections" do
      let(:wallet_transaction) do
        create(:wallet_transaction, wallet:, amount: "15.00", credit_amount: "15.00",
          invoice_requires_successful_payment:, skip_invoice_custom_sections: true)
      end

      before do
        create(:billing_entity_applied_invoice_custom_section, organization:,
          billing_entity:, invoice_custom_section: create(:invoice_custom_section, organization:))
        create(:wallet_applied_invoice_custom_section, organization:, wallet:,
          invoice_custom_section: create(:invoice_custom_section, organization:))
      end

      it "skips all sections without falling back to wallet or customer sections" do
        result = invoice_service.call
        expect(result.invoice.applied_invoice_custom_sections).to be_empty
      end
    end

    context "when wallet has skip_invoice_custom_sections and wallet_transaction has no opinion" do
      let(:wallet) { create(:wallet, customer:, skip_invoice_custom_sections: true) }

      before do
        create(:billing_entity_applied_invoice_custom_section, organization:,
          billing_entity:, invoice_custom_section: create(:invoice_custom_section, organization:))
      end

      it "skips all sections without falling back to customer sections" do
        result = invoice_service.call
        expect(result.invoice.applied_invoice_custom_sections).to be_empty
      end
    end

    it "does not enqueue an SendEmailJob" do
      expect do
        invoice_service.call
      end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
    end

    context "with lago_premium", :premium do
      it "enqueues an SendEmailJob" do
        expect do
          invoice_service.call
        end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
      end

      context "when organization does not have right email settings" do
        before { customer.billing_entity.update!(email_settings: []) }

        it "does not enqueue an SendEmailJob" do
          expect do
            invoice_service.call
          end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
        end
      end
    end

    it "calls SegmentTrackJob" do
      invoice = invoice_service.call.invoice

      expect(SegmentTrackJob).to have_been_enqueued.with(
        membership_id: CurrentContext.membership,
        event: "invoice_created",
        properties: {
          organization_id: invoice.organization.id,
          invoice_id: invoice.id,
          invoice_type: invoice.invoice_type
        }
      )
    end

    it "creates a payment" do
      result = invoice_service.call
      expect(Invoices::Payments::CreateJob).to have_been_enqueued.with(invoice: result.invoice, payment_provider: :stripe, payment_method_params: {})
    end

    context "with customer timezone" do
      before { customer.update!(timezone: "America/Los_Angeles") }

      let(:timestamp) { DateTime.parse("2022-11-25 01:00:00").to_i }

      it "assigns the issuing date in the customer timezone" do
        result = invoice_service.call

        expect(result.invoice.issuing_date.to_s).to eq("2022-11-24")
      end
    end

    context "with provided invoice" do
      let(:invoice) do
        create(:invoice, organization: customer.organization, customer:, invoice_type: :credit, status: :generating)
      end

      it "does not re-create an invoice" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice).to eq(invoice)

        expect(result.invoice.fees.count).to eq(1)

        expect(result.invoice.fees_amount_cents).to eq(1500)
        expect(result.invoice.taxes_amount_cents).to eq(0)
        expect(result.invoice.taxes_rate).to eq(0)
        expect(result.invoice.total_amount_cents).to eq(1500)

        expect(result.invoice).to be_finalized
      end
    end

    context "with wallet_transaction.invoice_requires_successful_payment", :premium do
      let(:invoice_requires_successful_payment) { true }

      it "creates an open invoice" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice).to be_open
        expect(Invoices::Payments::CreateJob).to have_been_enqueued.with(invoice: result.invoice, payment_provider: :stripe, payment_method_params: {})

        # These jobs should only be enqueued for finalized invoices
        expect(SegmentTrackJob).not_to have_been_enqueued
        expect(Invoices::GenerateDocumentsJob).not_to have_been_enqueued
        expect(SendWebhookJob).not_to have_been_enqueued
      end
    end

    context "when wallet_transaction was snapshotted on a different billing entity" do
      let(:snapshot_billing_entity) { create(:billing_entity, organization:) }
      let(:other_billing_entity) { create(:billing_entity, organization:) }
      let(:wallet_transaction) do
        create(
          :wallet_transaction,
          wallet:,
          billing_entity: snapshot_billing_entity,
          amount: "15.00",
          credit_amount: "15.00",
          invoice_requires_successful_payment:
        )
      end

      before do
        wallet.update!(billing_entity: other_billing_entity)
      end

      it "issues the invoice under the transaction's snapshotted entity, not the wallet's current one" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.billing_entity_id).to eq(snapshot_billing_entity.id)
      end
    end
  end
end
