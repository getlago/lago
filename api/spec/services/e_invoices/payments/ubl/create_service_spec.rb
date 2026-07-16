# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Payments::Ubl::CreateService, :premium do
  let(:organization) { create(:organization, premium_integrations: %w[issue_receipts]) }
  let(:payment) { create(:payment, organization:) }
  let(:xml_builder_double) { instance_double(Nokogiri::XML::Builder, to_xml: xml_content) }
  let(:xml_content) { "<xml>content</xml>" }

  describe "#call" do
    context "when payment exists" do
      it "builds the XML" do
        allow(Nokogiri::XML::Builder).to receive(:new).with(encoding: "UTF-8")
          .and_yield(xml_builder_double).and_return(xml_builder_double)

        allow(EInvoices::Payments::Ubl::Builder).to receive(:serialize)
          .with(xml: xml_builder_double, payment:)

        result = described_class.new(payment:).call
        expect(result).to be_success
        expect(result.xml).to be(xml_content)
      end
    end

    context "without payment" do
      let(:payment) { nil }

      it "returns a failed result" do
        result = described_class.new(payment:).call
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("payment_not_found")
      end
    end

    context "when issue_receipts is not enabled" do
      before do
        organization.update(premium_integrations: [])
      end

      it "returns a failed result" do
        result = described_class.new(payment:).call
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.message).to eq("feature_unavailable")
      end
    end
  end
end
