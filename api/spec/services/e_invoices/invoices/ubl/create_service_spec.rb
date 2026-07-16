# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Invoices::Ubl::CreateService do
  let(:invoice) { create(:invoice) }
  let(:xml_builder_double) { instance_double(Nokogiri::XML::Builder, to_xml: xml_content) }
  let(:xml_content) { "<xml>content</xml>" }

  describe "#call" do
    context "when invoice exists" do
      it "builds the XML" do
        allow(Nokogiri::XML::Builder).to receive(:new).with(encoding: "UTF-8")
          .and_yield(xml_builder_double).and_return(xml_builder_double)

        allow(EInvoices::Invoices::Ubl::Builder).to receive(:serialize)
          .with(xml: xml_builder_double, invoice:)

        result = described_class.new(invoice:).call
        expect(result).to be_success
        expect(result.xml).to be(xml_content)
      end
    end

    context "without invoice" do
      let(:invoice) { nil }

      it "returns a failed result" do
        result = described_class.new(invoice:).call
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end
  end
end
