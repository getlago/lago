# frozen_string_literal: true

FactoryBot.define do
  factory :recurring_rule_applied_invoice_custom_section, class: "RecurringTransactionRule::AppliedInvoiceCustomSection" do
    recurring_transaction_rule
    organization { recurring_transaction_rule&.organization || association(:organization) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
