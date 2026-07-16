# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::ProviderTaxes::ReportJob do
  let(:organization) { create(:organization) }
  let(:credit_note) { create(:credit_note, customer:) }
  let(:customer) { create(:customer, organization:) }

  let(:result) { BaseService::Result.new }

  before do
    allow(CreditNotes::ProviderTaxes::ReportService).to receive(:call)
      .with(credit_note:)
      .and_return(result)
  end

  context "when there is anrok customer" do
    let(:integration) { create(:anrok_integration, organization:) }
    let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

    before { integration_customer }

    it "calls successfully report service" do
      described_class.perform_now(credit_note:)

      expect(CreditNotes::ProviderTaxes::ReportService).to have_received(:call)
    end
  end

  context "when there is NOT anrok customer" do
    it "does not call report service" do
      described_class.perform_now(credit_note:)

      expect(CreditNotes::ProviderTaxes::ReportService).not_to have_received(:call)
    end
  end
end
