# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RecurringTransactionRules::UpdateService do
  let(:wallet) { create(:wallet) }
  let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }
  let(:params) do
    [
      {
        lago_id: recurring_transaction_rule.id,
        trigger: "interval",
        interval: "weekly",
        paid_credits: "105",
        granted_credits: "105",
        started_at: "2024-05-30T12:48:26Z",
        transaction_metadata:,
        invoice_custom_section: {skip_invoice_custom_sections: true}
      }
    ]
  end
  let(:transaction_metadata) { [] }

  describe "#call" do
    subject(:result) { described_class.call(wallet:, params:) }

    before { recurring_transaction_rule }

    it "updates an existing active recurring transaction rule" do
      rule = result.wallet.reload.recurring_transaction_rules.active.first

      expect(result.wallet.reload.recurring_transaction_rules.count).to eq(1)
      expect(rule).to have_attributes(
        granted_credits: 105.0,
        id: recurring_transaction_rule.id,
        interval: "weekly",
        method: "fixed",
        paid_credits: 105.0,
        started_at: Time.parse("2024-05-30T12:48:26Z"),
        threshold_credits: 0.0,
        trigger: "interval"
      )
    end

    context "when updating an inactive rule" do
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            trigger: "interval",
            interval: "weekly",
            paid_credits: "105",
            granted_credits: "105",
            invoice_custom_section: {skip_invoice_custom_sections: true}
          }
        ]
      end

      it "does not update inactive rules and creates a new one" do
        recurring_transaction_rule.mark_as_terminated!

        active_rule = result.wallet.reload.recurring_transaction_rules.active.first
        expect(result.wallet.reload.recurring_transaction_rules.count).to eq(2)
        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
        expect(active_rule).to have_attributes(
          granted_credits: 105,
          id: active_rule.id,
          interval: "weekly",
          method: "fixed",
          paid_credits: 105,
          trigger: "interval",
          skip_invoice_custom_sections: true
        )
      end
    end

    context "with added rule without id" do
      let(:params) do
        [
          {
            granted_credits: "105",
            interval: "weekly",
            method: "target",
            paid_credits: "105",
            target_ongoing_balance: "300",
            trigger: "interval",
            payment_method: {
              payment_method_id: nil,
              payment_method_type: "manual"
            }
          }
        ]
      end

      it "creates new recurring transaction rule and terminates existing" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
        expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)
        expect(rule).to have_attributes(
          granted_credits: 105.0,
          interval: "weekly",
          method: "target",
          paid_credits: 105.0,
          target_ongoing_balance: 300.0,
          threshold_credits: 0.0,
          trigger: "interval",
          payment_method_id: nil,
          payment_method_type: "manual"
        )
        expect(rule.id).not_to eq(recurring_transaction_rule.id)
      end
    end

    context "when paid_credits and granted_credits are explicitly null" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, wallet:, paid_credits: 200, granted_credits: 200)
      end
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            method: "target",
            trigger: "interval",
            interval: "monthly",
            target_ongoing_balance: "5300",
            paid_credits: nil,
            granted_credits: nil,
            threshold_credits: nil
          }
        ]
      end

      it "coerces nil credit values to 0.0 instead of raising NotNullViolation" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(rule).to have_attributes(
          id: recurring_transaction_rule.id,
          method: "target",
          trigger: "interval",
          interval: "monthly",
          target_ongoing_balance: 5300.0,
          paid_credits: 0.0,
          granted_credits: 0.0,
          threshold_credits: 0.0
        )
      end
    end

    context "when updating grants_target_top_up" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, wallet:, method: :target, target_ongoing_balance: 300, grants_target_top_up: false)
      end
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            method: "target",
            trigger: "interval",
            interval: "weekly",
            target_ongoing_balance: "300",
            grants_target_top_up: true
          }
        ]
      end

      it "updates the rule to grant credits" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(rule).to have_attributes(
          id: recurring_transaction_rule.id,
          method: "target",
          grants_target_top_up: true
        )
      end

      context "when flipping grants_target_top_up from true to false" do
        let(:recurring_transaction_rule) do
          create(:recurring_transaction_rule, wallet:, method: :target, target_ongoing_balance: 300, grants_target_top_up: true)
        end
        let(:params) do
          [
            {
              lago_id: recurring_transaction_rule.id,
              method: "target",
              trigger: "interval",
              interval: "weekly",
              target_ongoing_balance: "300",
              grants_target_top_up: false
            }
          ]
        end

        it "updates the rule to stop granting credits" do
          rule = result.wallet.reload.recurring_transaction_rules.active.first

          expect(rule).to have_attributes(
            id: recurring_transaction_rule.id,
            method: "target",
            grants_target_top_up: false
          )
        end
      end
    end

    context "when switching a granting target rule to fixed" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, wallet:, method: :target, target_ongoing_balance: 300, grants_target_top_up: true)
      end
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            paid_credits: "10",
            granted_credits: "10"
          }
        ]
      end

      it "clears grants_target_top_up to nil" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(rule).to have_attributes(method: "fixed", grants_target_top_up: nil)
      end
    end

    context "when switching a fixed rule to target without specifying grants_target_top_up" do
      let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:, method: :fixed) }
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            method: "target",
            trigger: "interval",
            interval: "weekly",
            target_ongoing_balance: "300"
          }
        ]
      end

      it "defaults grants_target_top_up to false" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(rule).to have_attributes(method: "target", grants_target_top_up: false)
      end
    end

    context "when updating a legacy target rule that carries a nil grants_target_top_up" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, wallet:, method: :target, target_ongoing_balance: 300).tap do |r|
          r.update_column(:grants_target_top_up, nil) # rubocop:disable Rails/SkipsModelValidations
        end
      end
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            trigger: "interval",
            interval: "monthly",
            target_ongoing_balance: "300"
          }
        ]
      end

      it "normalises the nil to false on save without changing the method" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(rule).to have_attributes(method: "target", grants_target_top_up: false)
      end
    end

    context "when empty array is sent as argument" do
      let(:params) { [] }

      it "terminates all existing recurring transaction rules" do
        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(0)
        expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)
      end
    end

    context "when creating a new rule without invoice_requires_successful_payment" do
      let(:wallet) { create(:wallet, invoice_requires_successful_payment: true) }
      let(:params) do
        [
          {
            trigger: "interval",
            interval: "weekly",
            paid_credits: "10",
            granted_credits: "10"
          }
        ]
      end

      it "defaults invoice_requires_successful_payment from the wallet" do
        rule = result.wallet.reload.recurring_transaction_rules.active.first
        expect(rule.invoice_requires_successful_payment).to eq(true)
      end
    end

    context "when sending transaction_metadata" do
      context "when transaction_metadata is valid" do
        let(:transaction_metadata) { [{"key" => "key"}, {"value" => "value"}] }

        it "updates existing recurring transaction rule with new transaction_metadata" do
          rule = result.wallet.reload.recurring_transaction_rules.active.first
          expect(rule.transaction_metadata).to eq(transaction_metadata)
        end
      end
    end

    context "when sending payment_method" do
      let(:payment_method) { create(:payment_method, organization: wallet.organization, customer: wallet.customer) }
      let(:payment_method_params) do
        {
          payment_method_id: payment_method.id,
          payment_method_type: "provider"
        }
      end
      let(:params) do
        [
          {
            lago_id: recurring_transaction_rule.id,
            trigger: "interval",
            interval: "weekly",
            paid_credits: "105",
            granted_credits: "105",
            started_at: "2024-05-30T12:48:26Z",
            payment_method: payment_method_params
          }
        ]
      end

      before { payment_method }

      context "with valid payment method" do
        it "updates existing recurring transaction rule with new payment method" do
          rule = result.wallet.reload.recurring_transaction_rules.active.first
          expect(rule.payment_method_id).to eq(payment_method.id)
          expect(rule.payment_method_type).to eq("provider")
        end
      end

      context "when payment method is already attached" do
        before do
          recurring_transaction_rule.payment_method = payment_method
          recurring_transaction_rule.payment_method_type = "provider"
        end

        let(:payment_method_params) do
          {
            payment_method_id: nil,
            payment_method_type: "provider"
          }
        end

        it "removes payment_method" do
          rule = result.wallet.reload.recurring_transaction_rules.active.first
          expect(rule.payment_method_id).to eq(nil)
          expect(rule.payment_method_type).to eq("provider")
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
          expect(result).not_to be_success
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
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
          expect(result).not_to be_success
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end
    end

    {
      "Updated Transaction Name" => "Updated Transaction Name",
      "" => nil,
      "   " => nil,
      nil => nil
    }.each do |transaction_name, expected_transaction_name|
      context "when transaction_name is #{transaction_name.inspect}" do
        let(:params) do
          [
            {
              lago_id: recurring_transaction_rule.id,
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105",
              transaction_name:
            }
          ]
        end

        it "updates existing recurring transaction rule with new transaction_name" do
          rule = result.wallet.reload.recurring_transaction_rules.active.first
          expect(rule.transaction_name).to eq(expected_transaction_name)
        end
      end
    end
  end
end
