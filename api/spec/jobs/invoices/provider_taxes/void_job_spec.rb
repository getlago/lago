# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ProviderTaxes::VoidJob do
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, customer:) }
  let(:customer) { create(:customer, organization:) }

  let(:result) { BaseService::Result.new }

  before do
    allow(Invoices::ProviderTaxes::VoidService).to receive(:call)
      .with(invoice:)
      .and_return(result)
  end

  context "when there is anrok customer" do
    let(:integration) { create(:anrok_integration, organization:) }
    let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

    before { integration_customer }

    it "calls successfully void service" do
      described_class.perform_now(invoice:)

      expect(Invoices::ProviderTaxes::VoidService).to have_received(:call)
    end
  end

  context "when there is avalara customer" do
    let(:integration) { create(:avalara_integration, organization:) }
    let(:integration_customer) { create(:avalara_customer, integration:, customer:) }

    before { integration_customer }

    it "calls successfully void service" do
      described_class.perform_now(invoice:)

      expect(Invoices::ProviderTaxes::VoidService).to have_received(:call)
    end
  end

  context "when there is NOT tax customer" do
    it "does not call void service" do
      described_class.perform_now(invoice:)

      expect(Invoices::ProviderTaxes::VoidService).not_to have_received(:call)
    end
  end
end
