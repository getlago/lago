# frozen_string_literal: true

FactoryBot.define do
  factory :billing_entity_applied_invoice_custom_section, class: "BillingEntity::AppliedInvoiceCustomSection" do
    organization
    billing_entity { organization&.default_billing_entity || association(:billing_entity) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
