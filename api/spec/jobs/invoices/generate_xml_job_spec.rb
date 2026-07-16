# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::GenerateXmlJob do
  let(:invoice) { create(:invoice) }

  let(:result) { BaseService::Result.new }
  let(:service_class) { Invoices::GenerateXmlService }
  let(:generate_service) do
    instance_double(Invoices::GenerateXmlService)
  end

  it "delegates to the Generate service" do
    allow(service_class).to receive(:new)
      .with(invoice:, context: "api")
      .and_return(generate_service)
    allow(generate_service).to receive(:call_with_middlewares)
      .and_return(result)

    described_class.perform_now(invoice)

    expect(service_class).to have_received(:new)
    expect(generate_service).to have_received(:call_with_middlewares)
  end
end
