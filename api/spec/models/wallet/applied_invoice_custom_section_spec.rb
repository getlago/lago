# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallet::AppliedInvoiceCustomSection do
  subject(:applied_invoice_custom_section) do
    create(:wallet_applied_invoice_custom_section)
  end

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:wallet) }
  it { is_expected.to belong_to(:invoice_custom_section) }
end
