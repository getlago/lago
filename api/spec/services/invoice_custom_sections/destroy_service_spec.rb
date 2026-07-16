# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::DestroyService do
  subject(:service_result) { described_class.call(invoice_custom_section:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

  before do
    allow(InvoiceCustomSections::DeselectAllService).to receive(:call!).and_call_original
    create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section:)
    create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section:)
  end

  describe "#call" do
    context "when destroy is successful" do
      it "discards the invoice custom section and destroys all selections" do
        result = service_result

        expect(result.invoice_custom_section).to be_discarded
        expect(billing_entity.applied_invoice_custom_sections).to be_empty
        expect(customer.applied_invoice_custom_sections).to be_empty
        expect(InvoiceCustomSections::DeselectAllService).to have_received(:call!)
          .with(section: invoice_custom_section)
      end
    end
  end
end
