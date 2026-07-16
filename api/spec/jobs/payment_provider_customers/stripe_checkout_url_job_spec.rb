# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::StripeCheckoutUrlJob do
  subject(:stripe_checkout_job) { described_class }

  let(:stripe_customer) { create(:stripe_customer) }

  let(:stripe_service) { instance_double(PaymentProviderCustomers::StripeService) }

  it "calls generate_checkout_url method" do
    allow(PaymentProviderCustomers::StripeService).to receive(:new)
      .with(stripe_customer)
      .and_return(stripe_service)
    allow(stripe_service).to receive(:generate_checkout_url)
      .and_return(BaseService::Result.new)

    stripe_checkout_job.perform_now(stripe_customer)

    expect(PaymentProviderCustomers::StripeService).to have_received(:new)
    expect(stripe_service).to have_received(:generate_checkout_url)
  end
end
