# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::DeselectAllService do
  describe "#call" do
    subject(:service_result) { described_class.call(section:) }

    let(:customer) { create(:customer) }
    let(:organization) { customer.organization }
    let(:billing_entity) { customer.billing_entity }
    let(:section) { create(:invoice_custom_section, organization:) }

    context "when the section is selected" do
      before do
        create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: section)
        create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: section)
      end

      it "deselects the section for the billing entity and customer" do
        expect { service_result }
          .to change(billing_entity.applied_invoice_custom_sections, :count).from(1).to(0)
          .and change(customer.applied_invoice_custom_sections, :count).from(1).to(0)
        expect(service_result).to be_success
      end
    end

    context "when the section is not selected" do
      it "returns a success" do
        expect(service_result).to be_success
      end
    end
  end
end
