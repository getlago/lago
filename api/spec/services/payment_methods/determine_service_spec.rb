# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::DetermineService do
  subject(:service) { described_class.new(invoice:, customer:, payment_method_params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:default_payment_method) { create(:payment_method, customer:, is_default: true) }
  let(:payment_method_params) { {} }

  before { default_payment_method }

  describe "#call" do
    context "when payment_method_params are present" do
      context "when payment_method_type is manual" do
        let(:invoice) { create(:invoice, customer:, organization:) }
        let(:payment_method_params) { {payment_method_type: "manual"} }

        it "returns nil" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to be_nil
        end
      end

      context "when payment_method_id is provided" do
        let(:invoice) { create(:invoice, customer:, organization:) }
        let(:override_payment_method) { create(:payment_method, customer:, is_default: false) }
        let(:payment_method_params) { {payment_method_id: override_payment_method.id} }

        it "returns the specified payment method" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(override_payment_method)
        end

        context "when the payment_method_id does not exist" do
          let(:payment_method_params) { {payment_method_id: "00000000-0000-0000-0000-000000000000"} }

          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end
      end

      context "when no payment_method_id is provided" do
        let(:invoice) { create(:invoice, customer:, organization:) }
        let(:payment_method_params) { {payment_method_type: "provider"} }

        it "returns the customer default payment method" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(default_payment_method)
        end
      end
    end

    context "when payment_method_params are absent" do
      context "with a subscription invoice" do
        let(:plan) { create(:plan, organization:) }
        let(:invoice) { create(:invoice, customer:, organization:, invoice_type: :subscription) }

        context "when subscription has no payment method configured" do
          let(:subscription) { create(:subscription, customer:, plan:, organization:) }

          before { create(:invoice_subscription, invoice:, subscription:) }

          it "returns the customer default payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(default_payment_method)
          end
        end

        context "when subscription has a payment method" do
          let(:subscription_payment_method) { create(:payment_method, customer:, is_default: false) }
          let(:subscription) { create(:subscription, customer:, plan:, organization:, payment_method: subscription_payment_method) }

          before { create(:invoice_subscription, invoice:, subscription:) }

          it "returns the subscription payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(subscription_payment_method)
          end
        end

        context "when subscription has manual payment method type" do
          let(:subscription) { create(:subscription, customer:, plan:, organization:, payment_method_type: "manual") }

          before { create(:invoice_subscription, invoice:, subscription:) }

          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end

        context "when invoice has no invoice subscriptions" do
          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end
      end

      context "with an advance_charges invoice" do
        let(:plan) { create(:plan, organization:) }
        let(:invoice) { create(:invoice, customer:, organization:, invoice_type: :advance_charges) }
        let(:subscription) { create(:subscription, customer:, plan:, organization:) }

        before { create(:invoice_subscription, invoice:, subscription:) }

        it "returns the customer default payment method" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(default_payment_method)
        end
      end

      context "with a progressive_billing invoice" do
        let(:plan) { create(:plan, organization:) }
        let(:invoice) { create(:invoice, customer:, organization:, invoice_type: :progressive_billing) }
        let(:subscription) { create(:subscription, customer:, plan:, organization:) }

        before { create(:invoice_subscription, invoice:, subscription:) }

        it "returns the customer default payment method" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(default_payment_method)
        end
      end

      context "with a credit invoice" do
        let(:wallet) { create(:wallet, customer:, organization:) }
        let(:invoice) { create(:invoice, :credit, customer:, organization:) }

        context "when invoice has no wallet transaction" do
          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end

        context "when wallet transaction has manual payment method type" do
          before { create(:wallet_transaction, wallet:, invoice:, source: :manual, payment_method_type: "manual") }

          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end

        context "when wallet transaction has a payment method" do
          let(:wt_payment_method) { create(:payment_method, customer:, is_default: false) }

          before { create(:wallet_transaction, wallet:, invoice:, source: :manual, payment_method: wt_payment_method) }

          it "returns the wallet transaction payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(wt_payment_method)
          end
        end

        context "when wallet transaction source is interval" do
          before { create(:wallet_transaction, wallet:, invoice:, source: :interval) }

          context "when recurring rule has manual payment method type" do
            before { create(:recurring_transaction_rule, wallet:, payment_method_type: "manual") }

            it "returns nil" do
              result = service.call

              expect(result).to be_success
              expect(result.payment_method).to be_nil
            end
          end

          context "when recurring rule has a payment method" do
            let(:rule_payment_method) { create(:payment_method, customer:, is_default: false) }

            before { create(:recurring_transaction_rule, wallet:, payment_method: rule_payment_method) }

            it "returns the recurring rule payment method" do
              result = service.call

              expect(result).to be_success
              expect(result.payment_method).to eq(rule_payment_method)
            end
          end

          context "when there is no active recurring rule" do
            it "falls through to the wallet configuration" do
              result = service.call

              expect(result).to be_success
              expect(result.payment_method).to eq(default_payment_method)
            end
          end
        end

        context "when wallet transaction source is threshold" do
          let(:rule_payment_method) { create(:payment_method, customer:, is_default: false) }

          before do
            create(:wallet_transaction, wallet:, invoice:, source: :threshold)
            create(:recurring_transaction_rule, wallet:, payment_method: rule_payment_method)
          end

          it "returns the recurring rule payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(rule_payment_method)
          end
        end

        context "when wallet has manual payment method type" do
          let(:wallet) { create(:wallet, customer:, organization:, payment_method_type: "manual") }

          before { create(:wallet_transaction, wallet:, invoice:, source: :manual) }

          it "returns nil" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to be_nil
          end
        end

        context "when wallet has a payment method" do
          let(:wallet_payment_method) { create(:payment_method, customer:, is_default: false) }
          let(:wallet) { create(:wallet, customer:, organization:, payment_method: wallet_payment_method) }

          before { create(:wallet_transaction, wallet:, invoice:, source: :manual) }

          it "returns the wallet payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(wallet_payment_method)
          end
        end

        context "when no payment method is configured on wallet-related objects" do
          before { create(:wallet_transaction, wallet:, invoice:, source: :manual) }

          it "returns the customer default payment method" do
            result = service.call

            expect(result).to be_success
            expect(result.payment_method).to eq(default_payment_method)
          end
        end
      end

      context "with a one_off invoice" do
        let(:invoice) { create(:invoice, customer:, organization:, invoice_type: :one_off) }

        it "returns the customer default payment method" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(default_payment_method)
        end
      end
    end
  end
end
