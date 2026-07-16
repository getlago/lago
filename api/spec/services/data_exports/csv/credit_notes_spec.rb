# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::Csv::CreditNotes do
  describe "#call" do
    subject(:result) { described_class.new(data_export_part:).call }

    let(:data_export) { create(:data_export, resource_type: "credit_notes", organization:) }
    let(:billing_entity) { create(:billing_entity) }
    let(:organization) { billing_entity.organization }
    let(:credit_notes) { create_pair(:credit_note, billing_entity:) }

    let(:data_export_part) do
      create(:data_export_part, data_export:, object_ids: credit_notes.pluck(:id))
    end

    let(:expected_rows) do
      credit_notes.map do |credit_note|
        [
          credit_note.id,
          credit_note.sequential_id,
          credit_note.invoice.self_billed,
          credit_note.issuing_date.iso8601,
          credit_note.customer.id,
          credit_note.customer.external_id,
          credit_note.customer.name,
          credit_note.customer.email,
          credit_note.customer.country,
          credit_note.customer.tax_identification_number,
          credit_note.number,
          credit_note.invoice.number,
          credit_note.invoice.purchase_order_number,
          credit_note.credit_status,
          credit_note.refund_status,
          credit_note.reason,
          credit_note.description,
          credit_note.currency,
          credit_note.total_amount_cents,
          credit_note.taxes_amount_cents,
          credit_note.sub_total_excluding_taxes_amount_cents,
          credit_note.coupons_adjustment_amount_cents,
          credit_note.offset_amount_cents,
          credit_note.credit_amount_cents,
          credit_note.balance_amount_cents,
          credit_note.refund_amount_cents,
          credit_note.file_url
        ].map(&:to_s)
      end
    end

    before { create(:credit_note) }

    after do
      file = result.csv_file
      file.close
      File.unlink(file.path)
    end

    it "adds serialized credit notes to csv" do
      credit_notes.each { |credit_note| credit_note.invoice.update!(purchase_order_number: "PO-12345") }

      expect(result).to be_success
      parsed_rows = CSV.parse(result.csv_file, nil_value: "")
      expect(parsed_rows).to eq(expected_rows)
      expect(parsed_rows.first).to include("PO-12345")
    end

    context "when organization has multiple billing_entities" do
      let(:billing_entity2) { create(:billing_entity, organization:) }
      let(:credit_note) { create(:credit_note, billing_entity:) }
      let(:data_export_part) do
        create(:data_export_part, data_export:, object_ids: [credit_note.id])
      end
      let(:expected_rows) do
        [[
          credit_note.id,
          credit_note.sequential_id,
          credit_note.invoice.self_billed,
          credit_note.issuing_date.iso8601,
          credit_note.customer.id,
          credit_note.customer.external_id,
          credit_note.customer.name,
          credit_note.customer.email,
          credit_note.customer.country,
          credit_note.customer.tax_identification_number,
          credit_note.number,
          credit_note.invoice.number,
          credit_note.invoice.purchase_order_number,
          credit_note.credit_status,
          credit_note.refund_status,
          credit_note.reason,
          credit_note.description,
          credit_note.currency,
          credit_note.total_amount_cents,
          credit_note.taxes_amount_cents,
          credit_note.sub_total_excluding_taxes_amount_cents,
          credit_note.coupons_adjustment_amount_cents,
          credit_note.offset_amount_cents,
          credit_note.credit_amount_cents,
          credit_note.balance_amount_cents,
          credit_note.refund_amount_cents,
          credit_note.file_url,
          credit_note.billing_entity.code
        ].map(&:to_s)]
      end

      before do
        billing_entity2
      end

      it "adds serialized credit notes to csv" do
        expect(result).to be_success
        parsed_rows = CSV.parse(result.csv_file, nil_value: "")
        expect(parsed_rows).to eq(expected_rows)
      end
    end
  end
end
