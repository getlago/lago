# frozen_string_literal: true

RSpec.describe WalletTransactions::Payments::GeneratePaymentUrlService do
  describe ".call" do
    subject(:result) { described_class.call(wallet_transaction:) }

    context "when wallet transaction does not exist" do
      let(:wallet_transaction) { nil }

      it "fails with wallet transaction not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("wallet_transaction_not_found")
      end
    end

    context "when wallet transaction exists" do
      let(:wallet_transaction) { build(:wallet_transaction, status:, transaction_status:) }

      context "when transactions status is purchased" do
        let(:transaction_status) { "purchased" }
        let(:status) { nil }

        context "when transaction is already settled" do
          let(:status) { "settled" }

          it "fails with wallet transaction already settled error" do
            expect(result).to be_failure
            expect(result.error.messages).to match(base: ["wallet_transaction_already_settled"])
          end
        end

        context "when transaction is not settled" do
          let(:status) { WalletTransaction::STATUSES.excluding(:settled).sample }

          context "when transaction's invoice is missing" do
            it "fails with no attached invoice error" do
              expect(result).to be_failure
              expect(result.error.messages).to match(base: ["wallet_transaction_has_no_attached_invoice"])
            end
          end

          context "when transaction's invoice is present" do
            let(:wallet_transaction) do
              create(:wallet_transaction, :with_invoice, status:, transaction_status:, customer:)
            end

            let(:customer) { create(:customer, :with_stripe_payment_provider) }
            let(:checkout_url) { "https://example.com" }

            before do
              allow(::Stripe::Checkout::Session).to receive(:create).and_return({"url" => checkout_url})

              allow(Invoices::Payments::GeneratePaymentUrlService)
                .to receive(:call).with(invoice: wallet_transaction.invoice).and_call_original
            end

            it "calls Invoices::Payments::GeneratePaymentUrlService" do
              subject

              expect(Invoices::Payments::GeneratePaymentUrlService)
                .to have_received(:call)
                .with(invoice: wallet_transaction.invoice)

              expect(result).to be_success
              expect(result.payment_url).to eq checkout_url
            end
          end
        end
      end

      context "when transactions status is not purchased" do
        let(:transaction_status) { WalletTransaction::TRANSACTION_STATUSES.excluding(:purchased).sample }
        let(:status) { nil }

        it "fails with wallet transaction not purchased error" do
          expect(result).to be_failure
          expect(result.error.messages).to match(base: ["wallet_transaction_not_purchased"])
        end
      end
    end
  end
end
