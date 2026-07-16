# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::Csv::InvoiceFees do
  let(:data_export) do
    create :data_export, :processing, resource_type: "invoice_fees", resource_query:
  end

  let(:data_export_part) do
    data_export.data_export_parts.create(index: 1, object_ids: [invoice.id], organization_id: data_export.organization_id)
  end

  let(:resource_query) do
    {
      currency:,
      customer_id:,
      customer_external_id:,
      invoice_type:,
      issuing_date_from:,
      issuing_date_to:,
      payment_dispute_lost:,
      payment_overdue:,
      payment_status:,
      search_term:,
      status:
    }
  end

  let(:currency) { "EUR" }
  let(:customer_external_id) { "custext123" }
  let(:customer_id) { "customer-lago-id-123" }
  let(:invoice_type) { "credit" }
  let(:issuing_date_from) { "2023-12-25" }
  let(:issuing_date_to) { "2024-07-01" }
  let(:payment_dispute_lost) { false }
  let(:payment_overdue) { true }
  let(:payment_status) { "pending" }
  let(:search_term) { "service ABC" }
  let(:status) { "finalized" }

  let(:invoice_serializer_klass) { class_double("V1::InvoiceSerializer") }
  let(:fee_serializer_klass) { class_double("V1::FeeSerializer") }
  let(:subscription_serializer_klass) { class_double("V1::SubscriptionSerializer") }

  let(:invoice_serializer) do
    instance_double("V1::InvoiceSerializer", serialize: serialized_invoice)
  end

  let(:fee_serializer) do
    instance_double("V1::FeeSerializer", serialize: serialized_fee)
  end

  let(:invoice) { create :invoice }
  let(:fee) { create :fee, invoice: }

  let(:serialized_invoice) do
    {
      lago_id: "292ef60b-9e0c-42e7-9f50-44d5af4162ec",
      number: "TWI-2B86-170-001",
      issuing_date: "2024-06-06"
    }
  end

  let(:serialized_fee) do
    {
      lago_id: "cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302",
      item: {
        type: "charge",
        code: "group",
        name: "group",
        description: "charge 1 description",
        invoice_display_name: "group",
        filter_invoice_display_name: "Converted to EUR",
        grouped_by: {models: "model_1"}
      },
      taxes_amount_cents: 50,
      total_amount_cents: 10000,
      total_amount_currency: "USD",
      units: "100.0",
      precise_unit_amount: "10.0",
      from_date: "2024-05-08T00:00:00+00:00",
      to_date: "2024-06-06T12:48:59+00:00"
    }
  end

  before do
    invoice
    fee

    allow(invoice_serializer_klass)
      .to receive(:new)
      .and_return(invoice_serializer)

    allow(fee_serializer_klass)
      .to receive(:new)
      .and_return(fee_serializer)
  end

  describe "#call" do
    subject(:result) do
      described_class.new(
        data_export_part:,
        invoice_serializer_klass:,
        fee_serializer_klass:
      ).call
    end

    it "generates the correct CSV output" do
      expected_csv = <<~CSV
        292ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{models: ""model_1""}",#{fee.subscription.external_id},#{fee.subscription.plan.code},2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
      CSV

      expect(result).to be_success

      file = result.csv_file
      generated_csv = file.read

      file.close
      File.unlink(file.path)

      expect(generated_csv).to eq(expected_csv)
    end
  end
end
