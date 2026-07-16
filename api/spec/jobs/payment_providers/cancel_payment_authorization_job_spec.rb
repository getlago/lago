# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::CancelPaymentAuthorizationJob do
  it "calls the Stripe API" do
    payment_provider = create(:stripe_provider)
    stub_request(:post, %r{stripe}).and_return(status: 200, body: "{}")

    described_class.perform_now(payment_provider:, id: "pi_123456789")

    expect(WebMock).to have_requested(:post, "https://api.stripe.com/v1/payment_intents/pi_123456789/cancel")
  end

  context "when the payment provider is not Stripe" do
    it "raises NotImplementedError for Adyen provider" do
      payment_provider = create(:adyen_provider)

      expect {
        described_class.perform_now(payment_provider:, id: "AUTH_123")
      }.to raise_error(
        NotImplementedError,
        "Cancelling payment authorization not implemented for adyen"
      )
    end
  end
end
