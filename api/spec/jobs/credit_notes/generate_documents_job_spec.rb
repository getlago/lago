# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::GenerateDocumentsJob do
  subject { described_class.perform_now(credit_note) }

  let(:credit_note) { create(:credit_note) }
  let(:result) { BaseService::Result.new }

  before do
    allow(CreditNotes::GeneratePdfService).to receive(:call).with(credit_note:, context: "api").and_return(result)
    allow(CreditNotes::GenerateXmlService).to receive(:call).with(credit_note:, context: "api").and_return(result)
  end

  it_behaves_like "a configurable queue", "pdfs", "SIDEKIQ_PDFS", "invoices" do
    let(:arguments) { credit_note }
  end

  it_behaves_like "a retryable on network errors job" do
    let(:service_class) { CreditNotes::GenerateXmlService }
    let(:job_arguments) { credit_note }
  end

  it "delegates to the Generate service" do
    subject

    expect(CreditNotes::GeneratePdfService).to have_received(:call)
    expect(CreditNotes::GenerateXmlService).to have_received(:call)
  end
end
