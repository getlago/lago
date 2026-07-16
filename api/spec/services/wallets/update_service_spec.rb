# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::UpdateService do
  subject(:result) { described_class.call(wallet:, params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:, allowed_fee_types: []) }
  let(:expiration_at) { (Time.current + 1.year).iso8601 }
  let(:priority) { 5 }

  describe "#call" do
    before do
      subscription
      wallet
    end

    let(:params) do
      {
        id: wallet&.id,
        name: "new name",
        priority:,
        expiration_at:,
        invoice_requires_successful_payment: true,
        paid_top_up_min_amount_cents: 1_00,
        paid_top_up_max_amount_cents: 1_000_00
      }
    end

    it "updates the wallet" do
      expect(result).to be_success

      expect(result.wallet.name).to eq("new name")
      expect(result.wallet.expiration_at.iso8601).to eq(expiration_at)
      expect(result.wallet.invoice_requires_successful_payment).to eq(true)
      expect(result.wallet.priority).to eq(priority)
      expect(wallet.paid_top_up_min_amount_cents).to eq(1_00)
      expect(wallet.paid_top_up_max_amount_cents).to eq(1_000_00)

      expect(Utils::ActivityLog).to have_produced("wallet.updated").after_commit.with(wallet)
    end

    it "sends a `wallet.updated` webhook" do
      expect { result }.to have_enqueued_job_after_commit(SendWebhookJob).with("wallet.updated", Wallet)
    end

    it "flags the customer wallets for refresh and enqueues a refresh job" do
      expect { result }.to have_enqueued_job_after_commit(Customers::RefreshWalletJob).with(customer)
      expect(customer.reload).to be_awaiting_wallet_refresh
    end

    describe "wallet refresh gating" do
      shared_examples "flags refresh" do
        it "flags the customer wallets for refresh and enqueues a refresh job" do
          expect { result }.to have_enqueued_job_after_commit(Customers::RefreshWalletJob).with(customer)
          expect(result).to be_success
          expect(customer.reload).to be_awaiting_wallet_refresh
        end
      end

      shared_examples "does not flag refresh" do
        it "does not flag the customer wallets for refresh nor enqueue a refresh job" do
          expect { result }.not_to have_enqueued_job(Customers::RefreshWalletJob)
          expect(result).to be_success
          expect(customer.reload).not_to be_awaiting_wallet_refresh
        end
      end

      context "when code changes" do
        let(:params) { {id: wallet.id, code: "new_code"} }

        include_examples "flags refresh"
      end

      context "when priority changes" do
        let(:params) { {id: wallet.id, priority: wallet.priority - 1} }

        include_examples "flags refresh"
      end

      context "when allowed_fee_types change" do
        let(:params) { {id: wallet.id, applies_to: {fee_types: %w[charge]}} }

        include_examples "flags refresh"
      end

      context "when a wallet_target is added" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:params) { {id: wallet.id, applies_to: {billable_metric_ids: [billable_metric.id]}} }

        before { CurrentContext.source = "graphql" }

        include_examples "flags refresh"
      end

      context "when a wallet_target is removed" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:params) { {id: wallet.id, applies_to: {billable_metric_ids: []}} }

        before do
          CurrentContext.source = "graphql"
          create(:wallet_target, wallet:, billable_metric:)
        end

        include_examples "flags refresh"
      end

      context "when code changes together with an invoice_custom_section update" do
        let(:params) do
          {
            id: wallet.id,
            code: "new_code",
            invoice_custom_section: {skip_invoice_custom_sections: true}
          }
        end

        include_examples "flags refresh"
      end

      context "when only name changes" do
        let(:params) { {id: wallet.id, name: "new name"} }

        include_examples "does not flag refresh"
      end

      context "when only expiration_at changes" do
        let(:params) { {id: wallet.id, expiration_at: (Time.current + 1.year).iso8601} }

        include_examples "does not flag refresh"
      end

      context "when only paid_top_up_* change" do
        let(:params) do
          {
            id: wallet.id,
            paid_top_up_min_amount_cents: 1_00,
            paid_top_up_max_amount_cents: 1_000_00
          }
        end

        include_examples "does not flag refresh"
      end

      context "when only payment_method changes" do
        let(:payment_method) { create(:payment_method, organization:, customer:) }
        let(:params) do
          {
            id: wallet.id,
            payment_method: {payment_method_id: payment_method.id, payment_method_type: "provider"}
          }
        end

        before { payment_method }

        include_examples "does not flag refresh"
      end

      context "when only recurring_transaction_rules change", :premium do
        let(:params) do
          {
            id: wallet.id,
            recurring_transaction_rules: [
              {trigger: "interval", interval: "weekly", paid_credits: "105", granted_credits: "105"}
            ]
          }
        end

        include_examples "does not flag refresh"
      end

      context "when only metadata changes" do
        let(:params) { {id: wallet.id, metadata: {"foo" => "bar"}} }

        include_examples "does not flag refresh"
      end

      context "when client resends a refresh-relevant attribute with the same value (no-op)" do
        let(:params) { {id: wallet.id, code: wallet.code, name: "new name"} }

        include_examples "does not flag refresh"
      end
    end

    context "when wallet is not found" do
      let(:wallet) { nil }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("wallet_not_found")

        expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
      end
    end

    context "with invalid priority" do
      let(:priority) { 55 }

      it "returns false and result has errors" do
        expect(result).not_to be_success
        expect(result.error.messages[:priority]).to eq(["value_is_invalid"])
      end
    end

    context "with invalid expiration_at" do
      context "when string cannot be parsed to date" do
        let(:expiration_at) { "invalid" }

        it "returns false and result has errors" do
          expect(result).not_to be_success
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when expiration_at is integer" do
        let(:expiration_at) { 123 }

        it "returns false and result has errors" do
          expect(result).not_to be_success
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when expiration_at is less than current time" do
        let(:expiration_at) { (Time.current - 1.year).iso8601 }

        it "returns false and result has errors" do
          expect(result).not_to be_success
          expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end
    end

    context "with recurring transaction rules", :premium do
      let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }
      let(:transaction_metadata) { [] }
      let(:rules) do
        [
          {
            trigger: "interval",
            interval: "weekly",
            paid_credits: "105",
            granted_credits: "105",
            transaction_metadata:
          }
        ]
      end
      let(:params) do
        {
          id: wallet.id,
          name: "new name",
          expiration_at:,
          recurring_transaction_rules: rules
        }
      end

      before { recurring_transaction_rule }

      it "creates a new rule and terminates the old one" do
        expect(result).to be_success

        rule = result.wallet.reload.recurring_transaction_rules.active.first

        expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
        expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)
        expect(rule.id).not_to eq(recurring_transaction_rule.id)
        expect(rule.trigger).to eq("interval")
        expect(rule.interval).to eq("weekly")
        expect(rule.threshold_credits).to eq(0.0)
        expect(rule.paid_credits).to eq(105.0)
        expect(rule.granted_credits).to eq(105.0)

        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end

      context "when editing existing interval rule" do
        let(:rules) do
          [
            {
              lago_id: recurring_transaction_rule.id,
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105"
            }
          ]
        end

        it "updates the rule" do
          expect(result).to be_success

          rule = result.wallet.reload.recurring_transaction_rules.active.first

          expect(result.wallet.reload.recurring_transaction_rules.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(0)
          expect(rule.id).to eq(recurring_transaction_rule.id)
          expect(rule.trigger).to eq("interval")
          expect(rule.interval).to eq("weekly")
          expect(rule.threshold_credits).to eq(0.0)
          expect(rule.paid_credits).to eq(105.0)
          expect(rule.granted_credits).to eq(105.0)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when changing the rule into threshold one" do
        let(:rules) do
          [
            {
              lago_id: recurring_transaction_rule.id,
              trigger: "threshold",
              threshold_credits: "205",
              paid_credits: "105",
              granted_credits: "105"
            }
          ]
        end

        it "updates the rule" do
          expect(result).to be_success

          rule = result.wallet.reload.recurring_transaction_rules.active.first

          expect(result.wallet.reload.recurring_transaction_rules.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(0)
          expect(rule.id).to eq(recurring_transaction_rule.id)
          expect(rule.trigger).to eq("threshold")
          expect(rule.threshold_credits).to eq(205.0)
          expect(rule.paid_credits).to eq(105.0)
          expect(rule.granted_credits).to eq(105.0)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when an empty array is sent as argument" do
        let(:rules) { [] }

        it "terminates all existing recurring transaction rules" do
          expect(result).to be_success
          expect(result.wallet.reload.recurring_transaction_rules.count).to eq(1)
          expect(result.wallet.reload.recurring_transaction_rules.active.count).to eq(0)
          expect(result.wallet.reload.recurring_transaction_rules.terminated.count).to eq(1)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when number of rules is incorrect" do
        let(:rules) do
          [
            {
              trigger: "interval",
              interval: "monthly",
              paid_credits: "105",
              granted_credits: "105"
            },
            {
              trigger: "threshold",
              threshold_credits: "1.0",
              paid_credits: "105",
              granted_credits: "105"
            }
          ]
        end

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_number_of_recurring_rules"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when trigger is invalid" do
        let(:rules) do
          [
            {
              trigger: "invalid",
              interval: "monthly",
              paid_credits: "105",
              granted_credits: "105"
            }
          ]
        end

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when threshold credits value is invalid" do
        let(:rules) do
          [
            {
              trigger: "threshold",
              threshold_credits: "abc",
              paid_credits: "105",
              granted_credits: "105"
            }
          ]
        end

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when transaction_rule.transaction_metadata is hash" do
        let(:transaction_metadata) { {} }

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])

          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      describe "paid credits validation" do
        let(:rules) do
          [
            {
              lago_id: recurring_transaction_rule&.id,
              method:,
              paid_credits:,
              trigger: "interval",
              interval: "weekly",
              granted_credits: "105",
              ignore_paid_top_up_limits:,
              target_ongoing_balance: "5"

            }
          ]
        end

        let(:method) { "fixed" }
        let(:paid_credits) { "10" }
        let(:ignore_paid_top_up_limits) { false }
        let(:recurring_transaction_rule) { nil }

        context "when method is not fixed" do
          let(:method) { "target" }

          it "creates recurring transaction rule" do
            expect { result }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
            expect(result).to be_success
          end
        end

        context "when paid credits is 0" do
          let(:paid_credits) { "0.000005" }

          it "creates recurring transaction rule" do
            expect { result }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
            expect(result).to be_success
          end
        end

        context "when paid credits exceeds wallet limits" do
          let(:paid_credits) { "1000" }

          before { wallet.update!(paid_top_up_max_amount_cents: 1_00) }

          it "fails with generic error when amount violates wallet limits" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to eq({recurring_transaction_rules: ["invalid_recurring_rule"]})
          end
        end

        context "when paid credits exceeds wallet limits but ignore limits flag is passed" do
          let(:paid_credits) { "1000" }
          let(:ignore_paid_top_up_limits) { true }

          before { wallet.update!(paid_top_up_max_amount_cents: 1_00) }

          it "creates recurring transaction rule" do
            expect { result }.to change { wallet.reload.recurring_transaction_rules.count }.by(1)
            expect(result).to be_success
          end
        end

        context "when paid credits is within wallet limits" do
          let(:paid_credits) { "105" }
          let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }

          before { wallet.update!(paid_top_up_min_amount_cents: 1_00) }

          it "creates recurring transaction rule" do
            expect { result }.to change { recurring_transaction_rule.reload.attributes }
            expect(result).to be_success
          end
        end

        context "when rule exists and listed in params" do
          let(:params) do
            {
              id: wallet.id,
              name: "new name",
              expiration_at:,
              paid_top_up_min_amount_cents: 1000
            }
          end

          before do
            create(:recurring_transaction_rule, wallet:, paid_credits: 1)
          end

          it "fails with generic error when amount violates wallet limits" do
            rule = wallet.reload.recurring_transaction_rules.sole
            expect { result }.not_to change { rule.reload.attributes }
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to eq({recurring_transaction_rules: ["invalid_recurring_rule"]})
          end
        end
      end
    end

    context "when recurring rule paid credits exceeds wallet limits", :premium do
      let(:params) do
        {
          id: wallet.id,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "weekly",
              method: "fixed",
              paid_credits: "1000",
              granted_credits: "0"
            }
          ]
        }
      end

      before { wallet.update!(paid_top_up_max_amount_cents: 1) }

      it "returns an error from nested service and does not enqueue webhook" do
        expect(result).to be_failure
        expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])
        expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
      end
    end

    context "with limitations" do
      let(:limitations) do
        {
          fee_types: %w[charge]
        }
      end
      let(:params) do
        {
          id: wallet.id,
          name: "new name",
          applies_to: limitations
        }
      end

      it "creates fee limitation" do
        expect(result).to be_success
        expect(result.wallet.reload.name).to eq(params[:name])
        expect(result.wallet.reload.allowed_fee_types).to eq(limitations[:fee_types])
        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end

      context "when an empty array is sent as argument" do
        let(:limitations) do
          {
            fee_types: []
          }
        end

        it "removes fee limitations" do
          expect(result).to be_success
          expect(result.wallet.reload.name).to eq(params[:name])
          expect(result.wallet.reload.allowed_fee_types).to eq(limitations[:fee_types])
          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when fee type is invalid" do
        let(:limitations) do
          {
            fee_types: %w[invalid]
          }
        end

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error.messages[:allowed_fee_types]).to eq(["invalid_fee_types"])
          expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "with new billable metric limitations" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:billable_metric_second) { create(:billable_metric, organization:) }
        let(:wallet_target) { create(:wallet_target, wallet:, billable_metric:) }
        let(:limitations) do
          {
            billable_metric_ids: [billable_metric.id, billable_metric_second.id]
          }
        end

        before do
          CurrentContext.source = "graphql"

          billable_metric_second
          wallet_target
        end

        it "creates new wallet target" do
          expect { subject }.to change(WalletTarget, :count).by(1)
        end

        context "with API context" do
          let(:limitations) do
            {
              billable_metric_codes: [billable_metric.code, billable_metric_second.code]
            }
          end

          before { CurrentContext.source = "api" }

          it "creates new wallet target" do
            expect { subject }.to change(WalletTarget, :count).by(1)
          end
        end

        context "with invalid billable metric" do
          let(:limitations) do
            {
              billable_metric_ids: [billable_metric.id, billable_metric_second.id, "invalid"]
            }
          end

          it "returns an error" do
            expect(result).not_to be_success
            expect(result.error.messages[:billable_metrics]).to eq(["invalid_identifier"])
          end
        end
      end

      context "with wallet targets to delete" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:wallet_target) { create(:wallet_target, wallet:, billable_metric:) }
        let(:limitations) do
          {
            billable_metric_ids: []
          }
        end

        before do
          CurrentContext.source = "graphql"

          wallet_target
        end

        it "deletes a wallet target" do
          expect { subject }.to change(WalletTarget, :count).by(-1)
        end
      end
    end

    context "with payment method" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:payment_method_params) do
        {
          payment_method_id: payment_method.id,
          payment_method_type: "provider"
        }
      end
      let(:params) do
        {
          id: wallet.id,
          name: "new name",
          payment_method: payment_method_params
        }
      end

      before { payment_method }

      it "attaches payment_method" do
        expect(result).to be_success
        expect(result.wallet.reload.name).to eq(params[:name])
        expect(result.wallet.reload.payment_method_id).to eq(payment_method_params[:payment_method_id])
        expect(result.wallet.reload.payment_method_type).to eq(payment_method_params[:payment_method_type])
        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end

      context "when payment method is already attached" do
        before do
          wallet.payment_method = payment_method
          wallet.payment_method_type = "provider"
        end

        let(:payment_method_params) do
          {
            payment_method_id: nil,
            payment_method_type: "provider"
          }
        end

        it "removes payment_method" do
          expect(result).to be_success
          expect(result.wallet.reload.name).to eq(params[:name])
          expect(result.wallet.reload.payment_method_id).to eq(nil)
          expect(result.wallet.reload.payment_method_type).to eq("provider")
          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
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

    context "when updating code" do
      let(:params) do
        {
          id: wallet.id,
          code: "updated_code",
          priority: 5
        }
      end

      it "updates the wallet code" do
        expect(result).to be_success
        expect(result.wallet.code).to eq("updated_code")
      end
    end

    context "when code is not provided in params" do
      let(:wallet) { create(:wallet, customer:, code: "existing_code") }
      let(:params) do
        {
          id: wallet.id,
          name: "updated name",
          priority: 5
        }
      end

      it "keeps the existing code" do
        expect(result).to be_success
        expect(result.wallet.code).to eq("existing_code")
      end
    end

    context "when updating values to nil" do
      let(:params) do
        {
          id: wallet&.id,
          name: nil,
          priority: nil,
          code: nil,
          expiration_at: nil,
          invoice_requires_successful_payment: nil,
          paid_top_up_min_amount_cents: nil,
          paid_top_up_max_amount_cents: nil
        }
      end

      it "doesn't fail and only updates not required values" do
        expect(result).to be_success
        expect(result.wallet.priority).not_to eq(nil)
        expect(result.wallet.code).not_to eq(nil)
        expect(result.wallet.invoice_requires_successful_payment).not_to eq(nil)

        expect(result.wallet.name).to eq(nil)
        expect(result.wallet.expiration_at).to eq(nil)
        expect(result.wallet.paid_top_up_min_amount_cents).to eq(nil)
        expect(result.wallet.paid_top_up_max_amount_cents).to eq(nil)
      end
    end

    context "when updating code to a value already taken for the customer" do
      before do
        create(:wallet, customer:, code: "taken_code")
      end

      let(:params) do
        {
          id: wallet.id,
          code: "taken_code",
          priority: 5
        }
      end

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.messages[:code]).to eq(["value_already_exist"])
      end
    end

    context "with metadata" do
      let(:params) do
        {
          id: wallet.id,
          name: "new name",
          priority: 5,
          metadata: {"foo" => "bar", "baz" => "qux"}
        }
      end

      it "creates metadata" do
        expect(result).to be_success
        expect(result.wallet.metadata).to be_present
        expect(result.wallet.metadata.value).to eq({"foo" => "bar", "baz" => "qux"})
      end

      context "when wallet has existing metadata" do
        before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value", "foo" => "old"}) }

        it "replaces all metadata" do
          expect(result).to be_success
          expect(result.wallet.metadata.value).to eq({"foo" => "bar", "baz" => "qux"})
        end
      end

      context "when partial_metadata is true" do
        subject(:result) { described_class.call(wallet:, params:, partial_metadata: true) }

        context "when wallet has existing metadata" do
          before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value", "foo" => "old"}) }

          it "merges metadata" do
            expect(result).to be_success
            expect(result.wallet.metadata.value).to eq({"old" => "value", "foo" => "bar", "baz" => "qux"})
          end
        end
      end

      context "when metadata is nil" do
        let(:params) do
          {
            id: wallet.id,
            name: "new name",
            priority: 5,
            metadata: nil
          }
        end

        context "when wallet has existing metadata" do
          before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value"}) }

          it "deletes all metadata" do
            expect(result).to be_success
            expect(result.wallet.reload.metadata).to be_nil
          end
        end
      end
    end

    context "when multi_entity_billing is enabled" do
      let!(:billing_entity) { create(:billing_entity, organization:, code: "be_code") }

      before do
        organization.update!(feature_flags: ["multi_entity_billing"])
      end

      context "when billing_entity_code is provided" do
        let(:params) do
          {
            id: wallet&.id,
            billing_entity_code: "be_code"
          }
        end

        it "assigns the billing entity to the wallet" do
          expect(result).to be_success
          expect(result.wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when billing_entity_id is provided" do
        let(:params) do
          {
            id: wallet&.id,
            billing_entity_id: billing_entity.id
          }
        end

        it "assigns the billing entity to the wallet" do
          expect(result).to be_success
          expect(result.wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when neither billing_entity_code nor billing_entity_id is provided" do
        let(:params) { {id: wallet&.id, name: "new name"} }

        it "leaves the wallet's billing entity unchanged" do
          expect(result).to be_success
          expect(result.wallet.billing_entity_id).to be_nil
        end
      end

      context "when the wallet already has a billing entity" do
        let!(:initial_billing_entity) { create(:billing_entity, organization:, code: "initial_be") }
        let(:wallet) { create(:wallet, customer:, billing_entity: initial_billing_entity, allowed_fee_types: []) }

        let(:params) do
          {
            id: wallet&.id,
            billing_entity_code: "be_code"
          }
        end

        it "switches the wallet's billing entity" do
          expect(result).to be_success
          expect(result.wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when billing_entity_code does not match any entity" do
        let(:params) do
          {
            id: wallet&.id,
            billing_entity_code: "nonexistent"
          }
        end

        it "returns a not found error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_id belongs to another organization" do
        let(:other_organization) { create(:organization) }
        let!(:other_billing_entity) { create(:billing_entity, organization: other_organization) }

        let(:params) do
          {
            id: wallet&.id,
            billing_entity_id: other_billing_entity.id
          }
        end

        it "returns a not found error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_code belongs to another organization" do
        let(:other_organization) { create(:organization) }

        let(:params) do
          {
            id: wallet&.id,
            billing_entity_code: "other_org_be"
          }
        end

        before { create(:billing_entity, organization: other_organization, code: "other_org_be") }

        it "returns a not found error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_id does not match any entity" do
        let(:params) do
          {
            id: wallet&.id,
            billing_entity_id: SecureRandom.uuid
          }
        end

        it "returns a not found error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("billing_entity")
        end
      end

      context "when both billing_entity_id and billing_entity_code are provided" do
        let!(:other_billing_entity) { create(:billing_entity, organization:, code: "other_be") }

        let(:params) do
          {
            id: wallet&.id,
            billing_entity_id: billing_entity.id,
            billing_entity_code: other_billing_entity.code
          }
        end

        it "billing_entity_id takes precedence" do
          expect(result).to be_success
          expect(result.wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when the wallet already has a billing_entity attached" do
        let(:current_entity) { create(:billing_entity, organization:, code: "current_be") }
        let(:other_entity) { create(:billing_entity, organization:, code: "other_be") }
        let(:wallet) { create(:wallet, customer:, billing_entity: current_entity, allowed_fee_types: []) }

        context "when billing_entity_id is nil" do
          let(:params) { {id: wallet&.id, billing_entity_id: nil} }

          it "clears the billing_entity_id" do
            expect(result).to be_success
            expect(result.wallet.billing_entity_id).to be_nil
          end
        end

        context "when billing_entity_id points at a different entity" do
          let(:params) { {id: wallet&.id, billing_entity_id: other_entity.id} }

          it "switches to the new entity" do
            expect(result).to be_success
            expect(result.wallet.billing_entity_id).to eq(other_entity.id)
          end
        end

        context "when billing_entity_id is unknown" do
          let(:params) { {id: wallet&.id, billing_entity_id: SecureRandom.uuid} }

          it "returns not_found_failure and leaves billing_entity_id unchanged" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.resource).to eq("billing_entity")
            expect(wallet.reload.billing_entity_id).to eq(current_entity.id)
          end
        end

        context "when billing_entity_code is nil" do
          let(:params) { {id: wallet&.id, billing_entity_code: nil} }

          it "clears the billing_entity_id" do
            expect(result).to be_success
            expect(result.wallet.billing_entity_id).to be_nil
          end
        end

        context "when billing_entity_code points at a different entity" do
          let(:params) { {id: wallet&.id, billing_entity_code: other_entity.code} }

          it "switches to the new entity" do
            expect(result).to be_success
            expect(result.wallet.billing_entity_id).to eq(other_entity.id)
          end
        end

        context "when no billing_entity key is sent" do
          let(:params) { {id: wallet&.id, name: "renamed"} }

          it "leaves billing_entity_id unchanged" do
            expect(result).to be_success
            expect(result.wallet.billing_entity_id).to eq(current_entity.id)
          end
        end

        context "when billing_entity_code is unknown" do
          let(:params) { {id: wallet&.id, billing_entity_code: "nonexistent"} }

          it "returns not_found_failure and leaves billing_entity_id unchanged" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.resource).to eq("billing_entity")
            expect(wallet.reload.billing_entity_id).to eq(current_entity.id)
          end
        end
      end
    end

    context "when multi_entity_billing is not enabled" do
      let(:params) do
        {
          id: wallet&.id,
          billing_entity_code: "be_code"
        }
      end

      before { create(:billing_entity, organization:, code: "be_code") }

      it "does not assign the billing entity even if code is provided" do
        expect(result).to be_success
        expect(result.wallet.billing_entity_id).to be_nil
      end
    end
  end
end
