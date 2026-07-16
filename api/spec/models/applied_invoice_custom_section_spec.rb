# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedInvoiceCustomSection do
  subject(:applied_invoice_custom_section) { build(:applied_invoice_custom_section) }

  it { is_expected.to belong_to(:invoice) }
  it { is_expected.to belong_to(:organization) }
end
