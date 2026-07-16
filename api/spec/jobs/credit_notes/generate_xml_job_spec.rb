# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::GenerateXmlJob do
  let(:credit_note) { create(:credit_note) }

  let(:result) { BaseService::Result.new }

  let(:generate_service) do
    instance_double(CreditNotes::GenerateXmlService)
  end

  it "delegates to the Generate service" do
    allow(CreditNotes::GenerateXmlService).to receive(:new)
      .with(credit_note:, context: "api")
      .and_return(generate_service)
    allow(generate_service).to receive(:call_with_middlewares)
      .and_return(result)

    described_class.perform_now(credit_note)

    expect(CreditNotes::GenerateXmlService).to have_received(:new)
    expect(generate_service).to have_received(:call_with_middlewares)
  end
end
