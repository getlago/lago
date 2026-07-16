# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::CreateFromParamsService do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, currency:) }
  let(:currency) { "EUR" }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) do
    create(
      :wallet,
      customer:,
      currency:,
      rate_amount:,
      balance_cents: 1000,
      credits_balance: 10.0,
      ongoing_balance_cents: 1000,
      credits_ongoing_balance: 10.0,
      invoice_requires_successful_payment: wallet_invoice_requires_successful_payment
    )
  end
  let(:wallet_invoice_requires_successful_payment) { false }
  let(:rate_amount) { 1 }

  before do
    subscription
  end

  describe "#call" do
    subject(:result) { described_class.call(organization:, params:) }

    let(:paid_credits) { "10.00" }
    let(:granted_credits) { "15.00" }
    let(:voided_credits) { "3.00" }
    let(:params) do
      {
        wallet_id: wallet.id,
        paid_credits:,
        granted_credits:,
        voided_credits:,
        **((name == :undefined) ? {} : {name:})
      }
    end
    let(:name) { :undefined }

    it "creates wallet transactions" do
      expect { subject }.to change(WalletTransaction, :count).by(3)
    end

    it "defaults priority to 50, name to nil and source to manual" do
      expect(result.wallet_transactions).to all(have_attributes(priority: 50, name: nil, source: "manual"))
      expect(WalletTransaction.where(wallet_id: wallet.id)).to all(have_attributes(priority: 50, name: nil, source: "manual"))
    end

    it "sets expected transaction status" do
      subject
      transactions = WalletTransaction.where(wallet_id: wallet.id)

      expect(transactions.find(&:purchased?).credit_amount).to eq(10)
      expect(transactions.find(&:granted?).credit_amount).to eq(15)
      expect(transactions.find(&:voided?).credit_amount).to eq(3)
    end

    it "enqueues the BillPaidCreditJob" do
      expect { subject }.to have_enqueued_job_after_commit(BillPaidCreditJob)
    end

    it "updates wallet balance based on granted and voided credits" do
      subject

      expect(wallet.reload.balance_cents).to eq(2200)
      expect(wallet.reload.credits_balance).to eq(22.0)
    end

    it "flags the customer wallets for refresh" do
      expect { subject }.to change { customer.reload.awaiting_wallet_refresh }.from(false).to(true)
    end

    it "enqueues a RefreshWalletJob to update the ongoing balance" do
      expect { subject }
        .to have_enqueued_job_after_commit(Customers::RefreshWalletJob).with(customer)
    end

    it "enqueues a SendWebhookJob for each wallet transaction" do
      expect do
        subject
      end.to have_enqueued_job(SendWebhookJob).thrice.with("wallet_transaction.created", WalletTransaction)
    end

    it "produces an activity log" do
      subject

      expect(Utils::ActivityLog).to have_received(:produce).thrice.with(an_instance_of(WalletTransaction), "wallet_transaction.created")
    end

    context "when rounding is applied" do
      let(:paid_credits) { "0" }
      let(:granted_credits) { "10.000000" }
      let(:voided_credits) { "4.28444999" }

      it "creates wallet transactions with rounded values" do
        transaction = subject.wallet_transactions.find(&:voided?)

        expect(transaction.credit_amount).to eq(4.28444)
        expect(transaction.amount).to eq(4.28)

        wallet.reload

        expect(wallet.credits_balance).to eq(15.71556)
        expect(wallet.balance.to_d).to eq(15.72)
      end
    end

    context "when voiding credits on a traceable wallet without trackable inbound balance" do
      let(:params) { {wallet_id: wallet.id, voided_credits: "3.00"} }

      it "returns a failed result with the underlying validation error" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq(amount_cents: ["exceeds_available_amount"])
        expect(result.wallet_transactions).to be_nil
      end

      it "does not create any wallet transaction" do
        expect { result }.not_to change(WalletTransaction, :count)
      end
    end

    context "with metadata parameter" do
      let(:metadata) { [{"key" => "valid_value", "value" => "also_valid"}] }
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          metadata: metadata
        }.with_indifferent_access
      end

      it "processes the transaction normally and includes the metadata" do
        expect(result).to be_success
        transactions = WalletTransaction.where(wallet_id: wallet.id)
        expect(transactions).to all(have_attributes(metadata: [{"key" => "valid_value", "value" => "also_valid"}]))
      end
    end

    context "with priority parameter" do
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          priority:
        }
      end

      let(:priority) { 25 }

      it "creates wallet transactions with specified priority" do
        expect(result.wallet_transactions).to all(have_attributes(priority:))
      end
    end

    context "with source parameter" do
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          granted_credits:,
          voided_credits:,
          source: :interval
        }
      end

      it "creates wallet transactions with specified source" do
        expect(result.wallet_transactions).to all(have_attributes(source: "interval"))
      end
    end

    context "with voided_invoice_id parameter" do
      let(:voided_invoice) { create(:invoice, :voided, organization:) }
      let(:params) do
        {
          wallet_id: wallet.id,
          granted_credits: "10",
          voided_invoice_id: voided_invoice.id
        }
      end

      it "creates granted transaction with voided_invoice_id" do
        expect(result.wallet_transactions.first.voided_invoice_id).to eq(voided_invoice.id)
      end
    end

    context "with name parameter" do
      let(:name) { "Custom Top-up Name" }

      it "creates wallet transactions with specified name" do
        expect(result.wallet_transactions).to all(have_attributes(name: "Custom Top-up Name"))
      end

      context "when name parameter is blank" do
        let(:name) { "" }

        it "creates wallet transactions with nil name" do
          expect(result.wallet_transactions).to all(have_attributes(name: nil))
        end
      end

      context "when name parameter is nil" do
        let(:name) { nil }

        it "creates wallet transactions with nil name" do
          expect(result.wallet_transactions).to all(have_attributes(name: nil))
        end
      end
    end

    context "with invoice_requires_successful_payment parameter" do
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          invoice_requires_successful_payment:
        }
      end

      let(:invoice_requires_successful_payment) { true }

      it "creates wallet transactions with specified invoice_requires_successful_payment" do
        expect(result.wallet_transactions).to all(have_attributes(invoice_requires_successful_payment:))
      end

      context "when invoice_requires_successful_payment parameter is false" do
        let(:invoice_requires_successful_payment) { false }

        context "when wallet's invoice_requires_successful_payment is true" do
          let(:wallet_invoice_requires_successful_payment) { true }

          it "creates wallet transactions with specified invoice_requires_successful_payment" do
            expect(result.wallet_transactions).to all(have_attributes(invoice_requires_successful_payment: false))
          end
        end
      end

      context "when invoice_requires_successful_payment parameter is null" do
        let(:invoice_requires_successful_payment) { nil }

        context "when wallet's invoice_requires_successful_payment is true" do
          let(:wallet_invoice_requires_successful_payment) { true }

          it "creates wallet transactions with specified invoice_requires_successful_payment" do
            expect(result.wallet_transactions).to all(have_attributes(invoice_requires_successful_payment: true))
          end
        end

        context "when wallet's invoice_requires_successful_payment is false" do
          it "creates wallet transactions with specified invoice_requires_successful_payment" do
            expect(result.wallet_transactions).to all(have_attributes(invoice_requires_successful_payment: false))
          end
        end
      end
    end

    context "with payment method" do
      it "sets correctly default payment method values" do
        expect(result).to be_success

        transactions = WalletTransaction.where(wallet_id: wallet.id)
        expect(transactions).to all(have_attributes(payment_method_id: nil))
        expect(transactions).to all(have_attributes(payment_method_type: "provider"))
      end

      context "when specific payment method is passed" do
        let(:payment_method) { create(:payment_method, organization:, customer:) }
        let(:params) do
          {
            wallet_id: wallet.id,
            paid_credits:,
            granted_credits:,
            voided_credits:,
            payment_method: {
              payment_method_id: payment_method.id,
              payment_method_type: "provider"
            },
            **((name == :undefined) ? {} : {name:})
          }
        end

        it "sets correctly payment method" do
          expect(result).to be_success

          transaction = WalletTransaction.where(wallet_id: wallet.id, transaction_status: :purchased).first
          expect(transaction.payment_method_id).to eq(payment_method.id)
          expect(transaction.payment_method_type).to eq("provider")
        end
      end
    end

    context "with validation error" do
      let(:paid_credits) { "-15.00" }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.messages[:paid_credits]).to eq(["invalid_paid_credits", "invalid_amount"])
      end

      context "when paid_credits is below the wallet minimum" do
        let(:paid_credits) { "5.00" }

        before { wallet.update! paid_top_up_min_amount_cents: 100_00 }

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:paid_credits]).to eq(["amount_below_minimum"])
        end

        context "when ignore_paid_top_up_limits is true" do
          let(:params) do
            {
              wallet_id: wallet.id,
              paid_credits:,
              ignore_paid_top_up_limits: true
            }
          end

          it "creates wallet transaction" do
            expect(result).to be_success
            expect(result.wallet_transactions.first.credit_amount).to eq(5)
          end
        end
      end

      context "when granted_credits round to zero monetary value" do
        let(:rate_amount) { 0.01 }
        let(:params) do
          {
            wallet_id: wallet.id,
            granted_credits: "0.4"
          }
        end

        it "fails and persists no wallet transaction" do
          expect { result }.not_to change(WalletTransaction, :count)
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:granted_credits]).to eq(["amount_rounds_to_zero"])
        end
      end

      context "with invalid payment method" do
        let(:payment_method) { create(:payment_method, organization:, customer:) }
        let(:params) do
          {
            wallet_id: wallet.id,
            paid_credits:,
            granted_credits:,
            voided_credits:,
            payment_method: payment_method_params,
            **((name == :undefined) ? {} : {name:})
          }
        end

        before { payment_method }

        context "when type is invalid" do
          let(:payment_method_params) do
            {
              payment_method_id: payment_method.id,
              payment_method_type: "invalid"
            }
          end

          it "fails" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
          end
        end

        context "when ID is invalid" do
          let(:payment_method_params) do
            {
              payment_method_id: "invalid",
              payment_method_type: "provider"
            }
          end

          it "fails" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
          end
        end
      end
    end

    context "with decimal value" do
      let(:paid_credits) { "4.399999" }

      it "creates wallet transaction with rounded value" do
        expect(result.wallet_transactions.first.credit_amount).to eq(4.40)
        expect(result.wallet_transactions.first.amount).to eq(4.40)
      end
    end

    context "with decimal value and small rate amount" do
      let(:paid_credits) { "4.399999" }
      let(:rate_amount) { 0.01 }

      it "creates wallet transaction with rounded value" do
        expect(result.wallet_transactions.first.credit_amount).to eq(4)
        expect(result.wallet_transactions.first.amount).to eq(0.04)
      end
    end

    context "with decimal value and large rate amount" do
      let(:paid_credits) { "4.3789" }
      let(:rate_amount) { 100 }

      it "creates wallet transaction with rounded value" do
        expect(result.wallet_transactions.first.credit_amount).to eq(4.3789)
        expect(result.wallet_transactions.first.amount).to eq(437.89)
      end
    end

    context "with decimal value and currency without digits" do
      let(:paid_credits) { "4.39999" }
      let(:currency) { "JPY" }

      it "creates wallet transaction with rounded value" do
        expect(result.wallet_transactions.first.credit_amount).to eq(4)
        expect(result.wallet_transactions.first.amount).to eq(4)
      end
    end

    context "when invoice_custom_section param exists" do
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          invoice_custom_section: {invoice_custom_section_codes: ["section_code_1"]}
        }
      end

      before do
        CurrentContext.source = "api"
        create(:invoice_custom_section, organization:, code: "section_code_1")
      end

      after { CurrentContext.source = nil }

      it "creates wallet transaction with invoice_custom_section" do
        applied_sections = result.wallet_transactions.first.applied_invoice_custom_sections
        expect(applied_sections.count).to eq(1)
        expect(applied_sections.first.invoice_custom_section.code).to eq("section_code_1")
      end
    end

    context "when invoice_custom_section_ids param exists (job context)" do
      let(:section) { create(:invoice_custom_section, organization:) }
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          invoice_custom_section: {skip_invoice_custom_sections: false, invoice_custom_section_ids: [section.id]}
        }
      end

      it "attaches the ICS to the wallet transaction by ID" do
        applied_sections = result.wallet_transactions.first.applied_invoice_custom_sections
        expect(applied_sections.count).to eq(1)
        expect(applied_sections.first.invoice_custom_section).to eq(section)
      end
    end

    context "when invoice_custom_section param has skip_invoice_custom_sections: true (job context)" do
      let(:params) do
        {
          wallet_id: wallet.id,
          paid_credits:,
          invoice_custom_section: {skip_invoice_custom_sections: true, invoice_custom_section_ids: []}
        }
      end

      it "marks the wallet transaction as skipping custom sections" do
        transaction = result.wallet_transactions.first
        expect(transaction.skip_invoice_custom_sections).to be(true)
        expect(transaction.applied_invoice_custom_sections).to be_empty
      end
    end

    context "when granted credits should be calculated using amount and wallet rate" do
      let(:granted_credits) { "10.34567" }
      let(:rate_amount) { 1.375 }

      it "creates wallet transaction with expected credit amount" do
        expect(result.wallet_transactions.find(&:granted?).credit_amount).to eq(10.34909) # 14.23/1.375
        expect(result.wallet_transactions.find(&:granted?).amount).to eq(14.23) # 10.34567*1.375
      end
    end
  end
end
