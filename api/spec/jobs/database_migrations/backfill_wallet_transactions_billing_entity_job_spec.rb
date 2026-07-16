# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillWalletTransactionsBillingEntityJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:) }

  context "when a wallet transaction has no billing entity" do
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, organization:, billing_entity: nil) }

    it "backfills it from the customer billing entity" do
      wallet_transaction

      expect { perform_job }.to change { wallet_transaction.reload.billing_entity_id }
        .from(nil).to(customer.billing_entity_id)
    end

    context "when the wallet has its own billing entity" do
      let(:wallet_billing_entity) { create(:billing_entity, organization:) }
      let(:wallet) { create(:wallet, customer:, organization:, billing_entity: wallet_billing_entity) }

      it "prefers the wallet billing entity over the customer one" do
        expect(wallet_billing_entity.id).not_to eq(customer.billing_entity_id)
        wallet_transaction

        perform_job

        expect(wallet_transaction.reload.billing_entity_id).to eq(wallet_billing_entity.id)
      end
    end

    context "when the transaction is attached to an invoice" do
      let(:invoice_billing_entity) { create(:billing_entity, organization:) }
      let(:invoice) { create(:invoice, customer:, organization:, billing_entity: invoice_billing_entity) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, organization:, invoice:, billing_entity: nil) }

      it "ignores the invoice billing entity and uses the customer one" do
        expect(invoice_billing_entity.id).not_to eq(customer.billing_entity_id)
        wallet_transaction

        perform_job

        expect(wallet_transaction.reload.billing_entity_id).to eq(customer.billing_entity_id)
      end
    end
  end

  context "when a wallet transaction already has a billing entity" do
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, organization:, billing_entity:) }

    it "leaves it untouched" do
      wallet_transaction

      expect { perform_job }.not_to change { wallet_transaction.reload.billing_entity_id }
    end
  end

  context "when there is more work after the batch" do
    before { stub_const("#{described_class}::BATCH_SIZE", 1) }

    it "enqueues the next batch" do
      create(:wallet_transaction, wallet:, organization:, billing_entity: nil)
      create(:wallet_transaction, wallet:, organization:, billing_entity: nil)

      expect { perform_job }.to have_enqueued_job(described_class)
    end
  end

  context "when there is no pending work" do
    it "does not enqueue another batch" do
      expect { perform_job }.not_to have_enqueued_job(described_class)
    end
  end
end
