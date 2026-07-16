# frozen_string_literal: true

FactoryBot.define do
  factory :customer_applied_invoice_custom_section, class: "Customer::AppliedInvoiceCustomSection" do
    organization
    billing_entity { organization&.default_billing_entity || association(:billing_entity) }
    customer { association(:customer, organization:, billing_entity:) }
    invoice_custom_section { association(:invoice_custom_section, organization:) }
  end
end
