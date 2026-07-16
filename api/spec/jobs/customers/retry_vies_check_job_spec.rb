# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::RetryViesCheckJob do
  let(:customer) { create(:customer) }

  it "finds the customer by ID and delegates to ViesCheckJob" do
    allow(Customers::ViesCheckJob).to receive(:perform_now)

    described_class.perform_now(customer.id)

    expect(Customers::ViesCheckJob).to have_received(:perform_now).with(customer)
  end
end
