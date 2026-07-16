# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RecurringTransactionRules::CreateService do
  subject(:create_service) { described_class.new(wallet:, wallet_params:) }

  let(:wallet) { create(:wallet, paid_top_up_min_amount_cents: 15_00) }
  let(:wallet_params) do
    {
      paid_credits: "100.0",
      granted_credits: "50.0",
      recurring_transaction_rules: [rule_params]
    }
  end

  let(:rule_params) do
    {
      interval: "monthly",
      method: "target",
      paid_credits: "10.0",
      granted_credits: "5.0",
      started_at: "2024-05-30T12:48:26Z",
      target_ongoing_balance: "100.0",
      trigger: "interval",
      ignore_paid_top_up_limits: "true"
    }
  end

  describe "#call" do
    context "when freemium" do
      it "does not create any recurring transaction rule" do
        expect { create_service.call }.not_to change { wallet.reload.recurring_transaction_rules.count }
      end
    end

    context "when premium", :premium do
      it "creates rule with expected attributes" do
        expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

        expect(wallet.recurring_transaction_rules.first).to have_attributes(
          granted_credits: 5.0,
          interval: "monthly",
          method: "target",
          paid_credits: 10.0,
          started_at: Time.parse("2024-05-30T12:48:26Z"),
          target_ongoing_balance: 100.0,
          threshold_credits: 0.0,
          trigger: "interval",
          invoice_requires_successful_payment: false,
          ignore_paid_top_up_limits: true
        )
      end

      context "when method is fixed" do
        let(:rule_params) do
          {
            trigger: "threshold",
            threshold_credits: "1.0",
            paid_credits:
          }
        end

        context "when paid and granted credits are omitted for rule" do
          let(:rule_params) do
            {
              trigger: "threshold",
              threshold_credits: "1.0"
            }
          end

          it "creates rule with paid and granted credits amounts inherited from wallet" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              granted_credits: 50.0,
              method: "fixed",
              paid_credits: 100.0,
              target_ongoing_balance: nil,
              threshold_credits: 1.0,
              trigger: "threshold"
            )
          end
        end

        context "when paid credits amount aligned with wallet limits" do
          let(:paid_credits) { "15" }

          it "creates rule with expected attributes" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              granted_credits: 0.0,
              method: "fixed",
              paid_credits: 15.0,
              target_ongoing_balance: nil,
              threshold_credits: 1.0,
              trigger: "threshold"
            )
          end
        end

        context "when paid credits amount exceeds wallet limits" do
          let(:paid_credits) { "5" }

          it "fails with validation error" do
            expect { create_service.call }.not_to change { wallet.reload.recurring_transaction_rules.count }

            expect(create_service.call).to be_failure
            expect(create_service.call.error.messages).to match({recurring_transaction_rules: ["invalid_recurring_rule"]})
          end
        end

        context "when paid credits amount is zero" do
          let(:paid_credits) { "0" }

          it "creates rule with expected attributes" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              granted_credits: 0.0,
              method: "fixed",
              paid_credits: 0.0,
              target_ongoing_balance: nil,
              threshold_credits: 1.0,
              trigger: "threshold"
            )
          end
        end
      end

      context "when method is target" do
        let(:rule_params) do
          {
            trigger: "threshold",
            method: "target",
            threshold_credits: "1.0",
            paid_credits: "5"
          }
        end

        it "creates rule with expected attributes ignoring wallet limits and grants_target_top_up defaulting to false" do
          expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

          expect(wallet.recurring_transaction_rules.first).to have_attributes(
            granted_credits: 0.0,
            grants_target_top_up: false,
            method: "target",
            paid_credits: 5.0,
            target_ongoing_balance: nil,
            threshold_credits: 1.0,
            trigger: "threshold"
          )
        end

        context "when grants_target_top_up is true" do
          let(:rule_params) do
            {
              trigger: "threshold",
              method: "target",
              threshold_credits: "1.0",
              grants_target_top_up: "true"
            }
          end

          it "creates rule with grants_target_top_up true" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              method: "target",
              grants_target_top_up: true
            )
          end
        end

        context "when grants_target_top_up is false" do
          let(:rule_params) do
            {
              trigger: "threshold",
              method: "target",
              threshold_credits: "1.0",
              grants_target_top_up: "false"
            }
          end

          it "creates rule with grants_target_top_up false" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              method: "target",
              grants_target_top_up: false
            )
          end
        end
      end

      context "when invoice_requires_successful_payment is present" do
        let(:rule_params) do
          {
            trigger: "threshold",
            threshold_credits: "1.0",
            invoice_requires_successful_payment: true
          }
        end

        it "creates rule with expected attributes" do
          expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

          expect(wallet.recurring_transaction_rules.first).to have_attributes(
            invoice_requires_successful_payment: true
          )
        end
      end

      context "when transaction metadata is present" do
        let(:rule_params) do
          {
            trigger: "threshold",
            threshold_credits: "1.0",
            transaction_metadata:
          }
        end

        let(:transaction_metadata) { [{"key" => "valid_value", "value" => "also_valid"}] }

        it "creates rule with expected attributes" do
          expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

          expect(wallet.recurring_transaction_rules.first).to have_attributes(
            transaction_metadata: transaction_metadata
          )
        end
      end

      context "when invoice_requires_successful_payment is blank" do
        let(:wallet) { create(:wallet, invoice_requires_successful_payment: true) }
        let(:wallet_params) do
          {
            paid_credits: "100.0",
            granted_credits: "50.0",
            recurring_transaction_rules: [{
              trigger: "threshold",
              threshold_credits: "1.0"
            }]
          }
        end

        it "follows the wallet configuration" do
          expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

          expect(wallet.recurring_transaction_rules.first).to have_attributes(
            invoice_requires_successful_payment: true
          )
        end
      end

      context "when expiration_at is set in the rule" do
        let(:expiration_at) { (Time.current + 1.year).iso8601 }
        let(:wallet_params) do
          {
            paid_credits: "100.0",
            granted_credits: "50.0",
            recurring_transaction_rules: [{
              trigger: "threshold",
              threshold_credits: "1.0",
              expiration_at:
            }]
          }
        end

        it "creates a rule with the correct expiration_at" do
          expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
          expect(wallet.recurring_transaction_rules.first.expiration_at).to eq(expiration_at)
        end
      end

      {
        "Custom Top-up Name" => "Custom Top-up Name",
        "" => nil,
        "   " => nil,
        nil => nil
      }.each do |transaction_name, expected_transaction_name|
        context "when transaction_name is #{transaction_name.inspect}" do
          let(:rule_params) do
            {
              trigger: "threshold",
              threshold_credits: "1.0",
              transaction_name:
            }
          end

          it "creates rule with expected transaction_name" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              transaction_name: expected_transaction_name
            )
          end
        end
      end

      context "with payment method" do
        let(:payment_method) { create(:payment_method, organization: wallet.organization, customer: wallet.customer) }
        let(:service_result) { create_service.call }
        let(:rule_params) do
          {
            trigger: "threshold",
            threshold_credits: "1.0",
            payment_method: payment_method_params
          }
        end
        let(:payment_method_params) do
          {
            payment_method_id: payment_method.id,
            payment_method_type: "provider"
          }
        end

        before { payment_method }

        it "creates recurring rule" do
          expect { service_result }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
          expect(service_result).to be_success

          expect(wallet.recurring_transaction_rules.first).to have_attributes(
            payment_method_id: payment_method.id,
            payment_method_type: "provider"
          )
        end

        context "when payment method id is nil" do
          let(:payment_method_params) do
            {
              payment_method_id: nil,
              payment_method_type: "provider"
            }
          end

          it "creates recurring rule" do
            expect { service_result }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
            expect(service_result).to be_success

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              payment_method_id: nil,
              payment_method_type: "provider"
            )
          end
        end

        context "when payment method type is not correct" do
          let(:payment_method_params) do
            {
              payment_method_id: payment_method.id,
              payment_method_type: "invalid"
            }
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
          end
        end

        context "when payment method id is not correct" do
          let(:payment_method_params) do
            {
              payment_method_id: "123",
              payment_method_type: "provider"
            }
          end

          it "returns an error" do
            expect(service_result).not_to be_success

            expect(service_result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
          end
        end
      end

      context "with invoice_custom_section" do
        let(:rule_params) do
          {
            interval: "monthly",
            method: "target",
            started_at: "2024-05-30T12:48:26Z",
            target_ongoing_balance: "100.0",
            trigger: "interval",
            invoice_custom_section:
          }
        end

        context "when skip" do
          let(:invoice_custom_section) do
            {skip_invoice_custom_sections: true}
          end

          it "creates the rule skipping sections" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            expect(wallet.recurring_transaction_rules.first).to have_attributes(
              skip_invoice_custom_sections: true
            )
          end
        end

        context "when attaching sections" do
          let(:invoice_custom_section) do
            {invoice_custom_section_codes: ["section_code_1", "section_code_2"]}
          end

          let(:section_1) { create(:invoice_custom_section, organization: wallet.organization, code: "section_code_1") }
          let(:section_2) { create(:invoice_custom_section, organization: wallet.organization, code: "section_code_2") }

          before do
            CurrentContext.source = "api"

            section_1
            section_2
          end

          it "creates the rule skipping sections" do
            expect { create_service.call }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)

            sections = wallet.recurring_transaction_rules.first.applied_invoice_custom_sections
            expect(sections.count).to eq(2)
            expect(sections.pluck(:invoice_custom_section_id)).to include(section_1.id, section_2.id)
          end
        end
      end
    end
  end
end
