# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::GenerateCheckoutUrlService do
  subject(:generate_checkout_url_service) { described_class.new(customer:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  describe ".call" do
    let(:stripe_provider) { create(:stripe_provider, organization:) }
    let(:stripe_customer_service) { instance_double(PaymentProviderCustomers::StripeService) }

    context "when payment provider is linked" do
      before do
        create(
          :stripe_customer,
          customer_id: customer.id,
          payment_provider: stripe_provider
        )

        customer.update(payment_provider: "stripe")

        allow(PaymentProviderCustomers::StripeService).to receive(:new)
          .and_return(stripe_customer_service)

        allow(stripe_customer_service).to receive(:generate_checkout_url)
          .with(send_webhook: false)
          .and_return(OpenStruct.new(checkout_url: "http://foo.bar"))
      end

      it "returns the generated checkout url" do
        result = generate_checkout_url_service.call

        expect(result.checkout_url).to eq("http://foo.bar")
      end
    end

    context "when customer is blank" do
      it "returns an error" do
        result = described_class.new(customer: nil).call

        expect(result).not_to be_success
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when payment provider is blank" do
      it "returns an error" do
        result = generate_checkout_url_service.call

        expect(result).not_to be_success
      end
    end
  end
end
