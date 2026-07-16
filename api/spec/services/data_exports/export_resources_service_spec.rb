# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::ExportResourcesService do
  subject(:result) { described_class.call(data_export:, batch_size:) }

  let(:organization) { data_export.organization }
  let(:batch_size) { 100 }
  let(:data_export) { create :data_export, resource_type: "invoices", format: "csv" }

  let(:issuing_date) { Date.new(2023, 12, 1) }

  let(:invoice) { create(:invoice, organization:, issuing_date:) }

  before do
    invoice
  end

  describe "#call" do
    it "updates the data export status to processing" do
      allow(data_export).to receive(:processing!)

      result
      expect(data_export).to have_received(:processing!)
    end

    it "splits up the data export into parts" do
      result
      expect(data_export.data_export_parts).not_to be_empty
      # only 1 export part should be create
      part = data_export.data_export_parts.sole
      expect(part.object_ids).to eq([invoice.id])
    end

    context "when there are many invoices" do
      # small batch size for easier testing
      let(:batch_size) { 2 }
      let(:invoice2) { create(:invoice, organization:, issuing_date: issuing_date + 1.day) }
      let(:invoice3) { create(:invoice, organization:, issuing_date: issuing_date + 2.days) }
      let(:invoice4) { create(:invoice, organization:, issuing_date: issuing_date + 3.days) }
      let(:invoice5) { create(:invoice, organization:, issuing_date: issuing_date + 4.days) }

      before do
        invoice2
        invoice3
        invoice4
        invoice5
      end

      it "splits up into many parts" do
        result

        expect(data_export.data_export_parts.size).to eq(3)
        part1 = data_export.data_export_parts.find_by index: 0
        part2 = data_export.data_export_parts.find_by index: 1
        part3 = data_export.data_export_parts.find_by index: 2
        expect(part1.object_ids).to eq([invoice5.id, invoice4.id])
        expect(part2.object_ids).to eq([invoice3.id, invoice2.id])
        expect(part3.object_ids).to eq([invoice.id])
      end
    end

    it "returns the data export result" do
      expect(result).to be_success

      expect(result.data_export).to be_processing
      expect(result.data_export.file).not_to be_present
    end

    context "when the data export is expired" do
      let(:data_export) { create(:data_export, expires_at: 1.hour.ago) }

      it "returns a service failure result" do
        expect(result).not_to be_success
        expect(result.error.code).to eq("data_export_expired")
      end
    end

    context "when the data export is already processed" do
      let(:data_export) { create(:data_export, :processing) }

      it "returns a service failure result" do
        expect(result).not_to be_success
        expect(result.error.code).to eq("data_export_processed")
      end
    end

    context "when an error occurs during processing" do
      before do
        allow(data_export)
          .to receive(:transaction)
          .and_raise(StandardError.new("error_message"))
      end

      it "returns a service failure result" do
        expect(result).not_to be_success
        expect(result.error.code).to eq("error_message")
        expect(data_export).to be_failed
      end
    end

    context "when resource type is credit_notes with types filter" do
      let(:data_export) do
        create(:data_export, resource_type: "credit_notes", format: "csv", resource_query: {"types" => ["credit"]})
      end

      let!(:credit_note_credit) do
        create(:credit_note, organization:, credit_amount_cents: 100, refund_amount_cents: 0, offset_amount_cents: 0)
      end

      let!(:credit_note_refund) do
        create(:credit_note, organization:, credit_amount_cents: 0, refund_amount_cents: 100, offset_amount_cents: 0)
      end

      it "only exports credit notes matching the types filter" do
        expect(result).to be_success

        part = data_export.data_export_parts.sole
        expect(part.object_ids).to include(credit_note_credit.id)
        expect(part.object_ids).not_to include(credit_note_refund.id)
      end
    end

    context "when resource type is not supported" do
      let(:data_export) { create :data_export, resource_type: "unknown" }

      it "returns a service failure result" do
        expect(result).not_to be_success
        expect(result.error.code).to eq(
          "'unknown' resource not supported"
        )
        expect(data_export).to be_failed
      end
    end
  end
end
