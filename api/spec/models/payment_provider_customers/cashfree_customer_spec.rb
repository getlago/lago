# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::CashfreeCustomer do
  subject(:cashfree_customer) { described_class.new(attributes) }

  let(:attributes) {}

  describe "#require_provider_payment_id?" do
    it { expect(cashfree_customer).not_to be_require_provider_payment_id }
  end
end
