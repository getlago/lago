# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::Csv::CreditNoteItems do
  describe "#call" do
    subject(:result) { described_class.new(data_export_part:).call }

    let(:data_export) { create(:data_export, resource_type: "credit_note_items") }
    let(:credit_notes) { create_pair(:credit_note, :with_items) }

    let(:data_export_part) do
      create(:data_export_part, data_export:, object_ids: credit_notes.pluck(:id))
    end

    let(:expected_rows) do
      credit_notes.flat_map(&:items).map do |item|
        [
          item.credit_note.id,
          item.credit_note.number,
          item.credit_note.invoice.number,
          item.credit_note.issuing_date.iso8601,
          item.id,
          item.fee.id,
          item.amount_currency,
          item.amount_cents
        ].map(&:to_s)
      end
    end

    before { create(:credit_note, :with_items) }

    after do
      file = result.csv_file
      file.close
      File.unlink(file.path)
    end

    it "adds serialized credit note items to csv" do
      expect(result).to be_success
      parsed_rows = CSV.parse(result.csv_file, nil_value: "")
      expect(parsed_rows).to eq(expected_rows)
    end
  end
end
