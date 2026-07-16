# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::AdyenCustomer do
  subject(:adyen_customer) { described_class.new(attributes) }

  let(:attributes) {}

  describe "#payment_method_id" do
    subject(:customer_payment_method_id) { adyen_customer.payment_method_id }

    let(:adyen_customer) { FactoryBot.build_stubbed(:adyen_customer) }
    let(:payment_method_id) { SecureRandom.uuid }

    before { adyen_customer.payment_method_id = payment_method_id }

    it "returns the payment method id" do
      expect(customer_payment_method_id).to eq payment_method_id
    end
  end

  describe "#require_provider_payment_id?" do
    it { expect(adyen_customer).to be_require_provider_payment_id }
  end
end
