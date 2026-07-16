# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Wallets::RecurringTransactionRuleSerializer do
  subject(:serializer) { described_class.new(recurring_transaction_rule, root_name: "recurring_transaction_rule") }

  let(:recurring_transaction_rule) { create(:recurring_transaction_rule) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["recurring_transaction_rule"]).to include(
      "lago_id" => recurring_transaction_rule.id,
      "method" => recurring_transaction_rule.method,
      "trigger" => recurring_transaction_rule.trigger,
      "interval" => recurring_transaction_rule.interval,
      "paid_credits" => recurring_transaction_rule.paid_credits.to_s,
      "started_at" => recurring_transaction_rule.started_at&.iso8601,
      "expiration_at" => recurring_transaction_rule.expiration_at&.iso8601,
      "status" => recurring_transaction_rule.status,
      "target_ongoing_balance" => recurring_transaction_rule.target_ongoing_balance,
      "threshold_credits" => recurring_transaction_rule.threshold_credits.to_s,
      "granted_credits" => recurring_transaction_rule.granted_credits.to_s,
      "grants_target_top_up" => false,
      "created_at" => recurring_transaction_rule.created_at.iso8601,
      "invoice_requires_successful_payment" => recurring_transaction_rule.invoice_requires_successful_payment,
      "transaction_metadata" => recurring_transaction_rule.transaction_metadata,
      "transaction_name" => "Recurring Transaction Rule",
      "ignore_paid_top_up_limits" => recurring_transaction_rule.ignore_paid_top_up_limits,
      "applied_invoice_custom_sections" => recurring_transaction_rule.applied_invoice_custom_sections
    )
    expect(result["recurring_transaction_rule"]["payment_method"]["payment_method_id"]).to eq(nil)
    expect(result["recurring_transaction_rule"]["payment_method"]["payment_method_type"]).to eq("provider")
  end

  context "when the rule is a target rule that grants the top-up" do
    let(:recurring_transaction_rule) { create(:recurring_transaction_rule, method: :target, grants_target_top_up: true) }

    it "serializes grants_target_top_up as true" do
      result = JSON.parse(serializer.to_json)

      expect(result["recurring_transaction_rule"]["grants_target_top_up"]).to be(true)
    end
  end
end
