# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::CreditNotes::Ubl::CreateService, type: :service do
  let(:credit_note) { create(:credit_note) }
  let(:xml_builder_double) { instance_double(Nokogiri::XML::Builder, to_xml: xml_content) }
  let(:xml_content) { "<xml>content</xml>" }

  describe "#call" do
    context "when credit_note exists" do
      it "builds the XML" do
        allow(Nokogiri::XML::Builder).to receive(:new).with(encoding: "UTF-8")
          .and_yield(xml_builder_double).and_return(xml_builder_double)

        allow(EInvoices::CreditNotes::Ubl::Builder).to receive(:serialize)
          .with(xml: xml_builder_double, credit_note:)

        result = described_class.new(credit_note:).call
        expect(result).to be_success
        expect(result.xml).to be(xml_content)
      end
    end

    context "without credit_note" do
      let(:credit_note) { nil }

      it "returns a failed result" do
        result = described_class.new(credit_note:).call
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("credit_note_not_found")
      end
    end
  end
end
