# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Hubspot::CreateCustomerAssociationJob do
  subject(:create_job) { described_class }

  let(:invoice) { create(:invoice) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Invoices::Hubspot::CreateCustomerAssociationService)
      .to receive(:call).and_return(result)
  end

  it "calls the aggregator create invoice hubspot service" do
    described_class.perform_now(invoice:)

    expect(Integrations::Aggregator::Invoices::Hubspot::CreateCustomerAssociationService).to have_received(:call)
  end
end
