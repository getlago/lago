# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer::AppliedInvoiceCustomSection do
  subject(:applied_invoice_custom_section) do
    create(:customer_applied_invoice_custom_section)
  end

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:billing_entity) }
  it { is_expected.to belong_to(:customer) }
  it { is_expected.to belong_to(:invoice_custom_section) }
end
