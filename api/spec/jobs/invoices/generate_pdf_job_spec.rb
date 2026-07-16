# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::GeneratePdfJob do
  let(:invoice) { create(:invoice) }

  let(:result) { BaseService::Result.new }

  it "delegates to the Generate service" do
    allow(Invoices::GeneratePdfService).to receive(:call)
      .with(invoice:, context: "api")
      .and_return(result)

    described_class.perform_now(invoice)

    expect(Invoices::GeneratePdfService).to have_received(:call)
  end
end
