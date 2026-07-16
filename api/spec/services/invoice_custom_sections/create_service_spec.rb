# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::CreateService do
  describe "#call" do
    subject(:service_result) { described_class.call(organization:, create_params:) }

    let(:organization) { create(:organization) }
    let(:create_params) { nil }

    context "with valid params" do
      let(:create_params) do
        {
          code: "test",
          details: "This text will be displayed in the invoice",
          display_name: "This will be the section title",
          name: "my firsts section"
        }
      end

      it "creates an invoice_custom_section that belongs to the organization" do
        expect { service_result }.to change(organization.invoice_custom_sections, :count).by(1)
        expect(service_result.invoice_custom_section).to be_persisted.and have_attributes(create_params)
      end
    end

    context "with invalid params" do
      let(:params) { {} }

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error).to be_a(BaseService::ValidationFailure)
        expect(service_result.error.messages[:code]).to eq(["value_is_mandatory"])
      end
    end
  end
end
