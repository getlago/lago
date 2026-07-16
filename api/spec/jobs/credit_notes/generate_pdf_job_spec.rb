# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::GeneratePdfJob do
  let(:credit_note) { create(:credit_note) }

  let(:result) { BaseService::Result.new }

  it "delegates to the Generate service" do
    allow(CreditNotes::GeneratePdfService).to receive(:call)
      .with(credit_note:, context: "api")
      .and_return(result)

    described_class.perform_now(credit_note)

    expect(CreditNotes::GeneratePdfService).to have_received(:call)
  end
end
