# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::WalletSerializer do
  subject(:serializer) { described_class.new(wallet, root_name: "wallet", includes: %i[limitations recurring_transaction_rules applied_invoice_custom_sections]) }

  let(:wallet) { create(:wallet, :with_top_up_limits, allowed_fee_types: %w[charge]) }
  let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }
  let(:wallet_target) { create(:wallet_target, wallet:) }
  let(:applied_invoice_custom_section) { create(:wallet_applied_invoice_custom_section, wallet:) }

  before do
    recurring_transaction_rule
    wallet_target
    applied_invoice_custom_section
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["wallet"]).to include(
      "lago_id" => wallet.id,
      "lago_customer_id" => wallet.customer_id,
      "external_customer_id" => wallet.customer.external_id,
      "billing_entity_code" => wallet.billing_entity.code,
      "status" => wallet.status,
      "currency" => wallet.currency,
      "name" => wallet.name,
      "priority" => wallet.priority,
      "rate_amount" => wallet.rate_amount.to_s,
      "created_at" => wallet.created_at.iso8601,
      "expiration_at" => wallet.expiration_at&.iso8601,
      "last_balance_sync_at" => wallet.last_balance_sync_at&.iso8601,
      "last_consumed_credit_at" => wallet.last_consumed_credit_at&.iso8601,
      "terminated_at" => wallet.terminated_at,
      "credits_balance" => wallet.credits_balance.to_s,
      "balance_cents" => wallet.balance_cents,
      "credits_ongoing_balance" => wallet.credits_ongoing_balance.to_s,
      "credits_ongoing_usage_balance" => wallet.credits_ongoing_usage_balance.to_s,
      "ongoing_balance_cents" => wallet.ongoing_balance_cents,
      "ongoing_usage_balance_cents" => wallet.ongoing_usage_balance_cents,
      "consumed_credits" => wallet.consumed_credits.to_s,
      "invoice_requires_successful_payment" => wallet.invoice_requires_successful_payment,
      "paid_top_up_min_amount_cents" => wallet.paid_top_up_min_amount_cents,
      "paid_top_up_max_amount_cents" => wallet.paid_top_up_max_amount_cents
    )
    expect(result["wallet"]["applies_to"]["fee_types"]).to eq(%w[charge])
    expect(result["wallet"]["applies_to"]["billable_metric_codes"]).to eq([wallet_target.billable_metric.code])
    expect(result["wallet"]["recurring_transaction_rules"].first["lago_id"]).to eq(recurring_transaction_rule.id)
    expect(result["wallet"]["applied_invoice_custom_sections"].first["lago_id"]).to eq(applied_invoice_custom_section.id)
    expect(result["wallet"]["payment_method"]["payment_method_id"]).to eq(nil)
    expect(result["wallet"]["payment_method"]["payment_method_type"]).to eq("provider")
  end

  describe "recurring_transaction_rules filtering" do
    let(:active_rule) { create(:recurring_transaction_rule, wallet:) }
    let(:active_future_expiration_rule) { create(:recurring_transaction_rule, wallet:, expiration_at: 1.day.from_now) }
    let(:active_past_expiration_rule) { create(:recurring_transaction_rule, wallet:, expiration_at: 1.day.ago) }
    let(:terminated_rule) { create(:recurring_transaction_rule, wallet:, status: :terminated) }

    before do
      active_rule
      active_future_expiration_rule
      active_past_expiration_rule
      terminated_rule
    end

    it "includes only active rules that have not expired" do
      result = JSON.parse(serializer.to_json)
      ids = result["wallet"]["recurring_transaction_rules"].map { |r| r["lago_id"] }

      expect(ids).to match_array([recurring_transaction_rule.id, active_rule.id, active_future_expiration_rule.id])
    end
  end
end
