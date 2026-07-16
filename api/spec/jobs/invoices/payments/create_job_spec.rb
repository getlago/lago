# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::CreateJob do
  let(:invoice) { create(:invoice) }
  let(:payment_provider) { "stripe" }

  it "calls the stripe create service" do
    allow(Invoices::Payments::CreateService).to receive(:call!)
      .with(invoice:, payment_provider:, payment_method_params: {})
      .and_return(BaseService::Result.new)

    described_class.perform_now(invoice:, payment_provider:, payment_method_params: {})

    expect(Invoices::Payments::CreateService).to have_received(:call!)
  end
end
