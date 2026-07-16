# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::GocardlessCheckoutUrlJob do
  subject(:gocardless_checkout_job) { described_class }

  let(:gocardless_customer) { create(:gocardless_customer) }

  let(:gocardless_service) { instance_double(PaymentProviderCustomers::GocardlessService) }

  it "calls generate_checkout_url method" do
    allow(PaymentProviderCustomers::GocardlessService).to receive(:new)
      .with(gocardless_customer)
      .and_return(gocardless_service)
    allow(gocardless_service).to receive(:generate_checkout_url)
      .and_return(BaseService::Result.new)

    gocardless_checkout_job.perform_now(gocardless_customer)

    expect(PaymentProviderCustomers::GocardlessService).to have_received(:new)
    expect(gocardless_service).to have_received(:generate_checkout_url)
  end
end
