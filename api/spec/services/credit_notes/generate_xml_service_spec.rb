# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::GenerateXmlService, type: :service do
  let(:context) { "graphql" }

  let(:organization) { create(:organization, name: "LAGO") }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", einvoicing:) }
  let(:einvoicing) { true }

  let(:credit_note) { create(:credit_note, status:, billing_entity:) }
  let(:status) { :finalized }

  let(:xml_service) { EInvoices::CreditNotes::Ubl::CreateService }
  let(:fake_xml) { "<xml>content</xml>" }
  let(:create_xml_result) { BaseService::Result.new.tap { |result| result.xml = fake_xml } }
  let(:blank_xml_path) { Rails.root.join("spec/fixtures/blank.xml") }

  before do
    credit_note
  end

  shared_examples "dont generate" do |section|
    it "does not generate the xml" do
      described_class.call(credit_note:, context:)

      expect(xml_service).not_to have_received(:call)
    end
  end

  describe "#call" do
    before do
      allow(xml_service).to receive(:call)
        .with(credit_note:)
        .and_return(create_xml_result)
    end

    it "generates the xml synchronously" do
      result = described_class.call(credit_note:, context:)

      expect(result.credit_note.xml_file).to be_present
    end

    context "when using temp files" do
      let(:xml_tempfile) { instance_double(Tempfile).as_null_object }

      before do
        allow(Tempfile).to receive(:new).with([credit_note.number, ".xml"]).and_return(xml_tempfile)
        allow(xml_tempfile).to receive(:path).and_return(blank_xml_path)
      end

      it "removes the temp file at the end" do
        described_class.call(credit_note:, context:)

        expect(xml_tempfile).to have_received(:unlink)
      end

      context "when error happens" do
        before do
          allow(credit_note).to receive(:save).and_raise(ActiveRecord::RecordInvalid.new)
        end

        it "always removes the temp file" do
          expect {
            described_class.call(credit_note:, context:)
          }.to raise_error(ActiveRecord::RecordInvalid)

          expect(xml_tempfile).to have_received(:unlink)
        end
      end
    end

    context "when cant generate" do
      context "with credit_note not found" do
        let(:credit_note) { nil }

        it "results in error" do
          result = described_class.call(credit_note:, context:)

          expect(result.success).to be_falsey
          expect(result.error.error_code).to eq("credit_note_not_found")
        end
      end

      context "with credit_note as draft" do
        let(:status) { :draft }

        it "results in error" do
          result = described_class.call(credit_note:, context:)

          expect(result.success).to be_falsey
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("is_draft")
        end
      end

      context "with already generated a file" do
        before do
          credit_note.xml_file.attach(
            io: StringIO.new(File.read(blank_xml_path)),
            filename: "credit_note.xml",
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
