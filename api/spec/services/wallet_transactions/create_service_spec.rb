# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::CreateService do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, currency:) }
  let(:currency) { "EUR" }
  let(:wallet_credit) { WalletCredit.new(wallet:, credit_amount:) }

  let(:wallet) do
    create(
      :wallet,
      customer:,
      currency:,
      balance_cents: 1000,
      credits_balance: 10.0,
      ongoing_balance_cents: 1000,
      credits_ongoing_balance: 10.0
    )
  end

  before do
    wallet
  end

  describe "#call" do
    subject(:result) { described_class.call(wallet:, wallet_credit:, **transaction_params) }

    context "with minimum arguments" do
      let(:credit_amount) { 100 }

      let(:transaction_params) do
        {
          status: :pending,
          transaction_type: :inbound,
          transaction_status: :purchased
        }
      end

      it "creates a wallet transaction" do
        expect { subject }.to change(WalletTransaction, :count).by(1)
      end

      it "sets default values" do
        expect(result.wallet_transaction)
          .to be_a(WalletTransaction)
          .and be_persisted
          .and have_attributes(
            invoice_requires_successful_payment: false,
            metadata: [],
            priority: 50,
            source: "manual"
          )
      end
    end

    context "with all arguments" do
      let(:credit_amount) { 1000 }
      let(:credit_note) { create(:credit_note) }
      let(:invoice) { create(:invoice) }
      let(:payment_method) { create(:payment_method, customer:, organization:) }
      let(:payment_method_params) do
        {
          payment_method_id: payment_method.id,
          payment_method_type: "provider"
        }
      end

      let(:transaction_params) do
        {
          status: :pending,
          transaction_type: :outbound,
          transaction_status: :granted,
          source: :threshold,
          metadata: [{key: "value"}],
          invoice_requires_successful_payment: true,
          settled_at: Date.yesterday,
          credit_note_id: credit_note.id,
          invoice_id: invoice.id,
          priority: 25,
          name: "Custom Transaction Name",
          payment_method: payment_method_params
        }
      end

      it "creates a wallet transaction" do
        expect { subject }.to change(WalletTransaction, :count).by(1)
      end

      it "sets all attributes" do
        wallet_transaction = result.wallet_transaction

        expect(wallet_transaction.status).to eq("pending")
        expect(wallet_transaction.transaction_type).to eq("outbound")
        expect(wallet_transaction.transaction_status).to eq("granted")
        expect(wallet_transaction.source).to eq("threshold")
        expect(wallet_transaction.metadata).to eq([{"key" => "value"}])
        expect(wallet_transaction.invoice_requires_successful_payment).to be true
        expect(wallet_transaction.settled_at).to eq(Date.yesterday)
        expect(wallet_transaction.credit_note_id).to eq(credit_note.id)
        expect(wallet_transaction.invoice_id).to eq(invoice.id)
        expect(wallet_transaction.credit_amount).to eq(credit_amount)
        expect(wallet_transaction.priority).to eq 25
        expect(wallet_transaction.name).to eq("Custom Transaction Name")
        expect(wallet_transaction.payment_method_id).to eq(payment_method.id)
        expect(wallet_transaction.payment_method_type).to eq("provider")
      end
    end

    context "with traceable wallet" do
      let(:credit_amount) { 100 }
      let(:wallet) { create(:wallet, customer:, currency:, traceable: true) }

      context "when transaction is inbound" do
        context "when transaction is granted" do
          let(:transaction_params) do
            {
              status: :settled,
              transaction_type: :inbound,
              transaction_status: :granted
            }
          end

          it "sets remaining_amount_cents to amount_cents" do
            wallet_transaction = result.wallet_transaction

            expect(wallet_transaction.remaining_amount_cents).to eq(wallet_transaction.amount_cents)
          end
        end

        context "when transaction is purchased" do
          let(:transaction_params) do
            {
              status: :settled,
              transaction_type: :inbound,
              transaction_status: :purchased
            }
          end

          it "does not set remaining_amount_cents" do
            wallet_transaction = result.wallet_transaction

            expect(wallet_transaction.remaining_amount_cents).to be_nil
          end
        end
      end

      context "when transaction is outbound" do
        let(:transaction_params) do
          {
            status: :settled,
            transaction_type: :outbound,
            transaction_status: :invoiced
          }
        end

        it "does not set remaining_amount_cents" do
          wallet_transaction = result.wallet_transaction

          expect(wallet_transaction.remaining_amount_cents).to be_nil
        end
      end
    end

    context "with non-traceable wallet" do
      let(:credit_amount) { 100 }
      let(:wallet) { create(:wallet, customer:, currency:, traceable: false) }

      let(:transaction_params) do
        {
          status: :settled,
          transaction_type: :inbound,
          transaction_status: :purchased
        }
      end

      it "does not set remaining_amount_cents" do
        wallet_transaction = result.wallet_transaction

        expect(wallet_transaction.remaining_amount_cents).to be_nil
      end
    end

    context "with billing entity snapshotting" do
      let(:credit_amount) { 100 }
      let(:wallet_billing_entity) { create(:billing_entity, organization:) }
      let(:explicit_billing_entity) { create(:billing_entity, organization:) }
      let(:wallet) { create(:wallet, customer:, currency:, billing_entity: wallet_billing_entity) }

      let(:transaction_params) do
        {
          status: :pending,
          transaction_type: :inbound,
          transaction_status: :purchased
        }
      end

      it "snapshots the wallet's effective billing entity on the transaction" do
        wallet_transaction = result.wallet_transaction

        expect(wallet_transaction.billing_entity_id).to eq(wallet_billing_entity.id)
      end

      context "when wallet has no explicit billing entity" do
        let(:wallet) { create(:wallet, customer:, currency:, billing_entity: nil) }

        it "snapshots the customer's billing entity via the wallet fallback" do
          wallet_transaction = result.wallet_transaction

          expect(wallet_transaction.billing_entity_id).to eq(customer.billing_entity_id)
        end
      end

      context "when an explicit billing_entity_id is passed" do
        let(:transaction_params) do
          {
            status: :settled,
            transaction_type: :outbound,
            transaction_status: :voided,
            billing_entity_id: explicit_billing_entity.id
          }
        end

        it "uses the explicit value over the wallet's entity" do
          wallet_transaction = result.wallet_transaction

          expect(wallet_transaction.billing_entity_id).to eq(explicit_billing_entity.id)
        end
      end
    end
  end
end
