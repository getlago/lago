# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::GocardlessCreateJob do
  let(:gocardless_customer) { create(:gocardless_customer) }

  let(:gocardless_service) { instance_double(PaymentProviderCustomers::GocardlessService) }

  it "calls the gocardless create service" do
    allow(PaymentProviderCustomers::GocardlessService).to receive(:new)
      .with(gocardless_customer)
      .and_return(gocardless_service)
    allow(gocardless_service).to receive(:create)
      .and_return(BaseService::Result.new)

    described_class.perform_now(gocardless_customer)

    expect(PaymentProviderCustomers::GocardlessService).to have_received(:new)
    expect(gocardless_service).to have_received(:create)
  end
end
