# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::MoneyhashCustomer do
  subject(:moneyhash_customer) { described_class.new(attributes) }

  let(:attributes) {}

  describe "#payment_method_id" do
    subject(:customer_payment_method_id) { moneyhash_customer.payment_method_id }

    let(:moneyhash_customer) { FactoryBot.build_stubbed(:moneyhash_customer) }
    let(:payment_method_id) { SecureRandom.uuid }

    before { moneyhash_customer.payment_method_id = payment_method_id }

    it "returns the payment method id" do
      expect(customer_payment_method_id).to eq payment_method_id
    end
  end

  describe "#require_provider_payment_id?" do
    it { expect(moneyhash_customer).to be_require_provider_payment_id }
  end
end
