# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentProviderCustomers::ProviderPaymentMethodsEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(%w[card sepa_debit us_bank_account bacs_debit link boleto crypto customer_balance])
  end
end
