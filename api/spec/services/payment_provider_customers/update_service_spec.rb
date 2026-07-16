# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::UpdateService do
  let(:customer) { create(:customer, payment_provider: provider_name.downcase) }
  let(:payment_provider) { create(:stripe_provider, organization: customer.organization) }
  let(:provider_name) { "Stripe" }
  let(:provider_service_class) { "PaymentProviderCustomers::#{provider_name}Service".constantize }
  let(:provider_service) { provider_service_class.new(provider_customer) }
  let(:provider_customer) { create(:"#{provider_name.downcase}_customer", customer:) }

  before do
    allow("PaymentProviderCustomers::#{provider_name}Service".constantize)
      .to receive(:new)
      .and_return(provider_service)

    allow(provider_service).to receive(:update).and_return(BaseService::Result.new)
    allow(Stripe::Customer).to receive(:update).and_return(true)
  end

  describe "#call" do
    before { payment_provider }

    it "updates the provider customer" do
      described_class.call(customer)

      expect(provider_service_class).to have_received(:new).with(provider_customer)
      expect(provider_service).to have_received(:update)
    end
  end
end
