# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Customers::FetchDefaultPaymentMethodJob, type: :job do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:provider_customer) do
    create(:stripe_customer, customer:, provider_customer_id: "cus_123", payment_provider: stripe_provider)
  end

  describe "#perform" do
    it "calls the FetchDefaultPaymentMethodService" do
      allow(PaymentProviders::Stripe::Customers::FetchDefaultPaymentMethodService)
        .to receive(:call!)
        .with(provider_customer:)

      described_class.perform_now(provider_customer)

      expect(PaymentProviders::Stripe::Customers::FetchDefaultPaymentMethodService)
        .to have_received(:call!)
        .with(provider_customer:)
    end
  end
end
