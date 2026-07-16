# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceipts::GenerateXmlService do
  let(:context) { "graphql" }
  let(:organization) { create(:organization, name: "LAGO") }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", einvoicing:) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, total_amount_cents: 1000, number: "INV-24680-OIC-E") }
  let(:payment) do
    create(:payment,
      customer:,
      payment_type: "manual",
      payable: invoice,
      currency: "BRL",
      amount_cents: 1000,
      reference: "its a payment",
      provider_payment_method_data: {last4: "4321"})
  end
  let(:payment_receipt) { create(:payment_receipt, payment:, organization:, billing_entity:) }
  let(:status) { :finalized }
  let(:einvoicing) { true }
  let(:blank_xml_path) { Rails.root.join("spec/fixtures/blank.xml") }
  let(:fake_xml) { "<xml>content</xml>" }
  let(:create_xml_result) { BaseService::Result.new.tap { |result| result.xml = fake_xml } }
  let(:xml_service) { EInvoices::Invoices::Ubl::CreateService }

  before do
    payment
  end

  shared_examples "dont generate" do |section|
    it "does not generate the xml" do
      described_class.call(payment_receipt:, context:)

      expect(xml_service).not_to have_received(:call)
    end
  end

  describe "#call" do
    before do
      allow(xml_service).to receive(:call)
        .with(payment_receipt:)
        .and_return(create_xml_result)
    end

    it "generates the xml synchronously" do
      result = described_class.call(payment_receipt:, context:)

      expect(result.payment_receipt.xml_file).to be_present
    end

    context "when using temp files" do
      let(:xml_tempfile) { instance_double(Tempfile).as_null_object }

      before do
        allow(Tempfile).to receive(:new).with([payment_receipt.number, ".xml"]).and_return(xml_tempfile)
        allow(xml_tempfile).to receive(:path).and_return(blank_xml_path)
      end

      it "removes the temp file at the end" do
        described_class.call(payment_receipt:, context:)

        expect(xml_tempfile).to have_received(:unlink)
      end

      context "when error happens" do
        before do
          allow(payment_receipt).to receive(:save).and_raise(ActiveRecord::RecordInvalid.new)
        end

        it "always removes the temp file" do
          expect {
            described_class.call(payment_receipt:, context:)
          }.to raise_error(ActiveRecord::RecordInvalid)

          expect(xml_tempfile).to have_received(:unlink)
        end
      end
    end

    context "when cant generate" do
      context "with payment not found" do
        let(:payment_receipt) { nil }

        it "results in error" do
          result = described_class.call(payment_receipt:, context:)

          expect(result).to be_failure
          expect(result.error.error_code).to eq("payment_receipt_not_found")
        end
      end

      context "with already generated a file" do
        before do
          payment_receipt.xml_file.attach(
            io: StringIO.new(File.read(blank_xml_path)),
            filename: "payment_receipt.xml",
            content_type: "application/xml"
          )
        end

        it_behaves_like "dont generate"
      end

      context "when country is not allowed" do
        before do
          billing_entity.country = "BR"
          billing_entity.save!(validate: false)
        end

        it_behaves_like "dont generate"
      end

      context "when einvoicing is disabled" do
        let(:einvoicing) { false }

        it_behaves_like "dont generate"
      end
    end
  end
end
