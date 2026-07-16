# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::RefreshWebhookJob do
  it "calls the refresh webhook service" do
    allow(PaymentProviders::Stripe::RefreshWebhookService).to receive(:call!)

    described_class.perform_now(instance_double(PaymentProviders::StripeProvider))

    expect(PaymentProviders::Stripe::RefreshWebhookService).to have_received(:call!)
  end
end
