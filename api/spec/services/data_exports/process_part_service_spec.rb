# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::ProcessPartService do
  subject(:result) { described_class.call(data_export_part:) }

  let(:data_export) { create :data_export, resource_type: "invoices", format: "csv" }
  let(:data_export_part) { create :data_export_part, data_export:, object_ids: [invoice.id] }
  let(:invoice) { create :invoice }
  let(:serialized_invoice) do
    {
      lago_id: "invoice-lago-id-123",
      sequential_id: "SEQ123",
      issuing_date: "2023-01-01",
      self_billed: false,
      customer: {
        name: "customer name",
        email: "customer@eamil.com",
        lago_id: "customer-lago-id-456",
        external_id: "CUST123",
        country: "US",
        tax_identification_number: "123456789"
      },
      number: "INV123",
      purchase_order_number: "PO-12345",
      invoice_type: "credit",
      payment_status: "pending",
      status: "finalized",
      file_url: "http://api.lago.com/invoice.pdf",
      currency: "USD",
      fees_amount_cents: 70000,
      coupons_amount_cents: 1655,
      taxes_amount_cents: 10500,
      credit_notes_amount_cents: 334,
      prepaid_credit_amount_cents: 1000,
      total_amount_cents: 77511,
      payment_due_date: "2023-02-01",
      payment_dispute_lost_at: "2023-12-22",
      payment_overdue: false,
      total_due_amount_cents: 27511,
      total_paid_amount_cents: 50000,
      total_offsetted_credit_note_amount_cents: 334
    }
  end
  let(:invoice_serializer) do
    instance_double("V1::InvoiceSerializer", serialize: serialized_invoice)
  end

  before do
    create(:credit_note, offset_amount_cents: 334, invoice:)
    allow(V1::InvoiceSerializer)
      .to receive(:new)
      .and_return(invoice_serializer)
  end

  describe "#call" do
    it "processes the part" do
      expected_csv = <<~CSV
        invoice-lago-id-123,SEQ123,false,2023-01-01,customer-lago-id-456,CUST123,customer name,customer@eamil.com,US,123456789,INV123,PO-12345,credit,pending,finalized,http://api.lago.com/invoice.pdf,USD,70000,1655,10500,334,1000,77511,2023-02-01,2023-12-22,false,27511,50000,334
      CSV
      expect(result).to be_success
      expect(result.data_export_part.csv_lines).to eq(expected_csv)
    end

    it "enqueues a job when the last part is completed" do
      expect { result }.to have_enqueued_job(DataExports::CombinePartsJob).with(data_export_part.data_export)
    end
  end

  context "when other parts have not been complete" do
    let(:other_part) { create :data_export_part, data_export:, object_ids: [invoice.id], index: 2 }

    before { other_part }

    it "does not enqueue a job" do
      expect { result }.not_to have_enqueued_job(DataExports::CombinePartsJob).with(data_export_part.data_export)
    end
  end
end
