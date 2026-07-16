# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransaction::AppliedInvoiceCustomSection do
  subject(:applied_invoice_custom_section) do
    create(:wallet_transaction_applied_invoice_custom_section)
  end

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:wallet_transaction) }
  it { is_expected.to belong_to(:invoice_custom_section) }
end
