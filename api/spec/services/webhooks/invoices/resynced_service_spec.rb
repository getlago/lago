# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Invoices::ResyncedService do
  subject(:webhook_service) { described_class.new(object: invoice) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.resynced", "invoice"

    it "calls the InvoiceSerializer with integration_customers included" do
      serializer_instance = instance_double(V1::InvoiceSerializer)
      allow(V1::InvoiceSerializer).to receive(:new).and_return(serializer_instance)
      allow(serializer_instance).to receive(:serialize).and_return({})

      webhook_service.call

      expect(V1::InvoiceSerializer).to have_received(:new).with(
        invoice,
        root_name: "invoice",
        includes: array_including(:customer, :integration_customers, :subscriptions, :fees, :credits, :applied_taxes)
      )
    end
  end
end
