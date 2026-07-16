# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::GocardlessCustomer do
  subject(:gocardless_customer) { described_class.new(attributes) }

  let(:attributes) {}

  describe "#require_provider_payment_id?" do
    it { expect(gocardless_customer).to be_require_provider_payment_id }
  end
end
