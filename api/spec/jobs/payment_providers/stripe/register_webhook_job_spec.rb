# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::RegisterWebhookJob do
  it "calls the register webhook service" do
    allow(PaymentProviders::Stripe::RegisterWebhookService).to receive(:call!)

    described_class.perform_now(instance_double(PaymentProviders::StripeProvider))

    expect(PaymentProviders::Stripe::RegisterWebhookService).to have_received(:call!)
  end
end
