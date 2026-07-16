# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::VoidService do
  subject(:void_service) { described_class.new(invoice:, params:) }

  let(:params) { {} }

  describe "#call" do
    context "when invoice is nil" do
      let(:invoice) { nil }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("invoice")
      end
    end

    context "when invoice is draft" do
      let(:invoice) { create(:invoice, :draft) }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("not_voidable")
      end
    end

    context "when the invoice is voided" do
      let(:invoice) { create(:invoice, status: :voided) }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("not_voidable")
      end
    end

    context "when the invoice is finalized" do
      let(:invoice) { create(:invoice, :subscription, subscriptions:, status: :finalized, payment_status:, payment_overdue: true) }
      let(:subscriptions) { create_list(:subscription, 1) }

      context "when the payment status is succeeded" do
        let(:payment_status) { :succeeded }

        it "voids the invoice" do
          result = void_service.call

          expect(result).to be_success
          expect(result.invoice).to be_voided
          expect(result.invoice.voided_at).to be_present
        end
      end

      context "when the payment status is not succeeded" do
        let(:payment_status) { [:pending, :failed].sample }

        it "voids the invoice" do
          result = void_service.call

          expect(result).to be_success
          expect(result.invoice).to be_voided
          expect(result.invoice.voided_at).to be_present
          # expect(result.invoice.balance_amount_cents).to eq(0)
        end

        it "enqueues a sync void invoice job" do
          expect do
            void_service.call
          end.to have_enqueued_job(Invoices::ProviderTaxes::VoidJob).with(invoice:)
        end

        it "marks the invoice's payment overdue as false" do
          expect { void_service.call }.to change(invoice, :payment_overdue).from(true).to(false)
        end

        it "flags lifetime usage for refresh" do
          create(:usage_threshold, plan: subscriptions.first.plan)

          void_service.call

          expect(invoice.subscriptions.first.lifetime_usage.recalculate_invoiced_usage).to be(true)
        end

        it "produces an activity log" do
          invoice = described_class.call(invoice:).invoice

          expect(Utils::ActivityLog).to have_produced("invoice.voided").after_commit.with(invoice)
        end

        context "when the invoice has applied credits from the wallet" do
          let(:wallet) { create(:wallet, credits_balance: 100, balance_cents: 100) }
          let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, transaction_type: "outbound", amount: 100, credit_amount: 100) }

          before do
            wallet_transaction
            allow(WalletTransactions::RecreditService).to receive(:call).and_call_original
          end

          it "recredits the wallet transaction" do
            void_service.call
            expect(WalletTransactions::RecreditService).to have_received(:call).with(wallet_transaction: wallet_transaction)
            expect(wallet.wallet_transactions.count).to eq(2)
            expect(wallet.reload.credits_balance).to eq(200)
          end
        end

        context "when the invoice has applied credits from inactive wallet" do
          let(:wallet) { create(:wallet, credits_balance: 100, balance_cents: 100) }
          let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, transaction_type: "outbound", amount: 100, credit_amount: 100) }

          before do
            wallet_transaction
            allow(WalletTransactions::RecreditService).to receive(:call).and_call_original
          end

          it "dont recredit the wallet transaction" do
            wallet.mark_as_terminated!
            void_service.call
            expect(WalletTransactions::RecreditService).not_to have_received(:call)
            expect(wallet.wallet_transactions.count).to eq(1)
            expect(wallet.reload.credits_balance).to eq(100)
          end
        end

        context "when the invoice has credits from applied coupons" do
          let(:coupon) { create(:coupon) }
          let(:applied_coupon) { create(:applied_coupon, coupon: coupon) }
          let!(:credit) { create(:credit, invoice: invoice, applied_coupon: applied_coupon) }

          before do
            allow(AppliedCoupons::RecreditService).to receive(:call!).and_call_original
          end

          it "calls the recredit service for applied coupons" do
            void_service.call
            expect(AppliedCoupons::RecreditService).to have_received(:call!).with(credit: credit)
          end
        end

        context "when the invoice has credits from credit notes" do
          let(:credit_note) { create(:credit_note) }
          let!(:credit) { create(:credit, invoice: invoice, credit_note: credit_note) }

          before do
            allow(CreditNotes::RecreditService).to receive(:call!).and_call_original
          end

          it "dont call the recredit service for credit notes" do
            void_service.call
            expect(CreditNotes::RecreditService).not_to have_received(:call!).with(credit: credit)
          end
        end

        context "when invoice is a purchase credits invoice" do
          let(:invoice) { create(:invoice, :credit, status: :finalized, payment_status:, payment_overdue: true) }
          let(:payment_status) { [:pending, :failed].sample }
          let(:wallet) { create(:wallet, credits_balance: 100, balance_cents: 100) }
          let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, transaction_type: "inbound", amount: 100, credit_amount: 100) }

          before do
            wallet_transaction
            allow(WalletTransactions::RecreditService).to receive(:call).and_call_original
          end

          it "voids the invoice" do
            result = void_service.call

            expect(result).to be_success
            expect(result.invoice).to be_voided
            expect(result.invoice.voided_at).to be_present
          end

          it "does not recredit the wallet transaction" do
            void_service.call

            expect(wallet.wallet_transactions.count).to eq(1)
            expect(wallet.reload.credits_balance).to eq(100)
            expect(WalletTransactions::RecreditService).not_to have_received(:call)
          end
        end
      end
    end

    describe "when generate credit note is true" do
      let(:params) { {generate_credit_note: true} }

      context "when invoice is nil" do
        let(:invoice) { nil }

        it "returns a failure" do
          result = void_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("invoice")
        end
      end

      context "when the invoice is voided", :premium do
        let(:invoice) { create(:invoice, status: :voided) }

        it "returns a failure" do
          result = void_service.call
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("not_voidable")
        end
      end

      context "when the invoice has progressive billing credits", :premium do
        let(:params) { {generate_credit_note: true, credit_amount: 200} }
        let(:organization) { create(:organization) }
        let(:customer) { create(:customer, organization:) }
        let(:plan) { create(:plan, organization:) }
        let(:subscription) { create(:subscription, customer:, organization:, plan:) }
        let(:invoice) do
          create(
            :invoice,
            customer:,
            organization:,
            invoice_type: :subscription,
            status: :finalized,
            payment_status: :pending,
            fees_amount_cents: 400,
            progressive_billing_credit_amount_cents: 200,
            sub_total_excluding_taxes_amount_cents: 200,
            sub_total_including_taxes_amount_cents: 200,
            total_amount_cents: 200
          )
        end
        let(:charge) { create(:standard_charge, plan:) }
        let(:invoice_subscription) do
          create(:invoice_subscription, invoice:, subscription:, organization:)
        end
        let(:fee) do
          create(
            :charge_fee,
            invoice:,
            subscription:,
            charge:,
            amount_cents: 400,
            precise_amount_cents: 400,
            precise_coupons_amount_cents: 0,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0
          )
        end

        before do
          invoice_subscription
          fee
        end

        it "creates the requested credit note from the net remaining amount" do
          result = void_service.call

          expect(result).to be_success
          expect(result.invoice).to be_voided

          credit_note = invoice.credit_notes.find_by!(credit_status: :available)
          expect(credit_note.total_amount_cents).to eq(200)
          expect(credit_note.credit_amount_cents).to eq(200)
          expect(credit_note.items.sole.amount_cents).to eq(200)
        end
      end
    end

    describe "guard against concurrent calls" do
      let(:invoice) { create(:invoice, status: :finalized) }

      context "with two threads racing on the same invoice", transaction: false do
        # Separate in-memory instances of the same database record
        let!(:invoice_instances) do
          Array.new(2) do
            inv = Invoice.find(invoice.id)

            allow(inv).to receive(:void!).and_wrap_original do |original, *args|
              sleep(0.05)
              original.call(*args)
            end

            inv
          end
        end

        it "voids the invoice exactly once and rejects other attempts" do
          allow(LifetimeUsages::FlagRefreshFromInvoiceService).to receive(:call).and_call_original

          results = Concurrent::Array.new

          threads = invoice_instances.map do |inv|
            Thread.new do
              results << described_class.new(invoice: inv).call
            end
          end

          threads.each(&:join)

          successes = results.count(&:success?)
          rejections = results.count { |r| !r.success? && r.error.code == "not_voidable" }

          expect(successes).to eq(1)
          expect(rejections).to eq(1)
          expect(invoice.reload).to be_voided
          expect(LifetimeUsages::FlagRefreshFromInvoiceService).to have_received(:call).once
        end
      end
    end
  end
end
