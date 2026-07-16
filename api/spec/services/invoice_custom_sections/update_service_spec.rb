# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::UpdateService do
  subject(:service_result) { described_class.call(invoice_custom_section:, update_params:) }

  let(:organization) { create(:organization) }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }
  let(:update_params) { nil }

  describe "#call" do
    context "with valid params" do
      let(:update_params) { {name: "Updated Name"} }

      it "updates the invoice custom section" do
        result = service_result

        expect(result).to be_success
        expect(result.invoice_custom_section.name).to eq("Updated Name")
      end
    end

    context "with invalid params" do
      let(:update_params) { {name: nil} }

      it "handles validation errors" do
        expect(service_result).not_to be_success
        expect(service_result.error).to be_a(BaseService::ValidationFailure)
        expect(service_result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end
  end
end
