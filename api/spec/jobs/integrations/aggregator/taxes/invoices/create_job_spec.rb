# frozen_string_literal: true

require "rails_helper"

describe Integrations::Aggregator::Taxes::Invoices::CreateJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Taxes::Invoices::CreateService).to receive(:call!).and_return(result)
  end

  it "calls CreateService with the invoice and its fees" do
    described_class.perform_now(invoice:)

    expect(Integrations::Aggregator::Taxes::Invoices::CreateService)
      .to have_received(:call!).with(invoice:, fees: invoice.fees)
  end
end
