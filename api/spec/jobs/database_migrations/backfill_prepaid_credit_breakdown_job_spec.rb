# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillPrepaidCreditBreakdownJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  # Builds an invoice that consumed prepaid credit, with consumption rows linking
  # its outbound transaction to granted/purchased inbound transactions.
  def create_consumed_invoice(invoice_organization: organization, invoice_customer: customer, granted_cents: 0, purchased_cents: 0, status: :finalized, prepaid_credit_amount_cents: granted_cents + purchased_cents)
    wallet = create(:wallet, customer: invoice_customer, organization: invoice_organization, traceable: true)
    invoice = create(:invoice,
      organization: invoice_organization,
      customer: invoice_customer,
      status:,
      prepaid_credit_amount_cents:,
      prepaid_granted_credit_amount_cents: nil,
      prepaid_purchased_credit_amount_cents: nil)

    outbound = create(:wallet_transaction,
      wallet:, organization: invoice_organization,
      transaction_type: :outbound, status: :settled, invoice:)

    {granted: granted_cents, purchased: purchased_cents}.each do |status, cents|
      next unless cents.positive?

      inbound = create(:wallet_transaction,
        wallet:, organization: invoice_organization,
        transaction_type: :inbound, transaction_status: status, status: :settled)
      create(:wallet_transaction_consumption,
        organization: invoice_organization,
        inbound_wallet_transaction: inbound,
        outbound_wallet_transaction: outbound,
        consumed_amount_cents: cents)
    end

    invoice
  end

  describe "#perform" do
    it "fills both breakdown columns from consumption data" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to eq(100)
      expect(invoice.prepaid_purchased_credit_amount_cents).to eq(200)
    end

    it "leaves a column nil when its amount is zero" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 0)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to eq(100)
      expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "skips invoices whose customer is not fully traceable" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200)
      create(:wallet, customer:, organization:, traceable: false)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
      expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "skips invoices that are not finalized or voided" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200, status: :draft)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
      expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "processes voided invoices" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200, status: :voided)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to eq(100)
      expect(invoice.prepaid_purchased_credit_amount_cents).to eq(200)
    end

    it "skips invoices whose consumption ledger does not reconcile" do
      # prepaid_credit_amount_cents (500) != consumed total (300) → inconsistent, skip
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200, prepaid_credit_amount_cents: 500)

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
      expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "does not overwrite invoices that already have a breakdown" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200)
      invoice.update_columns(prepaid_granted_credit_amount_cents: 999) # rubocop:disable Rails/SkipsModelValidations

      described_class.perform_now(organization.id)

      invoice.reload
      expect(invoice.prepaid_granted_credit_amount_cents).to eq(999)
      expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "only processes the given organization" do
      other_organization = create(:organization)
      other_customer = create(:customer, organization: other_organization)
      other_invoice = create_consumed_invoice(
        invoice_organization: other_organization,
        invoice_customer: other_customer,
        granted_cents: 100, purchased_cents: 200
      )

      described_class.perform_now(organization.id)

      other_invoice.reload
      expect(other_invoice.prepaid_granted_credit_amount_cents).to be_nil
      expect(other_invoice.prepaid_purchased_credit_amount_cents).to be_nil
    end

    it "re-enqueues the next batch with an incremented batch_number" do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      create_consumed_invoice(granted_cents: 100, purchased_cents: 200)

      expect { described_class.perform_now(organization.id, 1) }
        .to have_enqueued_job(described_class).with(organization.id, 2)
    end

    it "does not re-enqueue when there is no work left" do
      expect { described_class.perform_now(organization.id) }
        .not_to have_enqueued_job(described_class)
    end

    it "is idempotent" do
      invoice = create_consumed_invoice(granted_cents: 100, purchased_cents: 200)

      described_class.perform_now(organization.id)
      expect(described_class.pending_count(organization.id)).to eq(0)

      expect { described_class.perform_now(organization.id) }
        .not_to change { invoice.reload.attributes.slice("prepaid_granted_credit_amount_cents", "prepaid_purchased_credit_amount_cents") }
    end
  end

  describe ".pending_count" do
    it "counts only computable, not-yet-filled invoices in scope" do
      create_consumed_invoice(granted_cents: 100, purchased_cents: 200)

      expect(described_class.pending_count(organization.id)).to eq(1)

      described_class.perform_now(organization.id)
      expect(described_class.pending_count(organization.id)).to eq(0)
    end
  end
end
