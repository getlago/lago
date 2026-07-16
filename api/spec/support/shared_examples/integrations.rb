# frozen_string_literal: true

RSpec.shared_examples "syncs invoice" do
  context "when it should sync invoice" do
    let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
    let(:integration) { create(:netsuite_integration, organization:, sync_invoices: true) }

    before do
      allow(Integrations::Aggregator::Invoices::CreateJob).to receive(:perform_later)
      integration_customer
      service_call
    end

    it "enqueues Integrations::Aggregator::Invoices::CreateJob" do
      expect(Integrations::Aggregator::Invoices::CreateJob).to have_received(:perform_later)
    end
  end
end

RSpec.shared_examples "syncs credit note" do
  context "when it should sync credit note" do
    let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
    let(:integration) { create(:netsuite_integration, organization:, sync_credit_notes: true) }

    before do
      allow(Integrations::Aggregator::CreditNotes::CreateJob).to receive(:perform_later)
      integration_customer
      service_call
    end

    it "enqueues Integrations::Aggregator::CreditNotes::CreateJob" do
      expect(Integrations::Aggregator::CreditNotes::CreateJob).to have_received(:perform_later)
    end
  end
end

RSpec.shared_examples "syncs payment" do
  context "when it should sync payment" do
    let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
    let(:integration) { create(:netsuite_integration, organization:, sync_payments: true) }

    before do
      allow(Integrations::Aggregator::Payments::CreateJob).to receive(:perform_later)
      integration_customer
      service_call
    end

    it "enqueues Integrations::Aggregator::Payments::CreateJob" do
      expect(Integrations::Aggregator::Payments::CreateJob).to have_received(:perform_later)
    end
  end
end

RSpec.shared_examples "throttles!" do |*providers|
  before { allow(service).to receive(:throttle!) }

  it "calls throttle!" do
    service.call
    expect(service).to have_received(:throttle!).with(*providers)
  end
end
