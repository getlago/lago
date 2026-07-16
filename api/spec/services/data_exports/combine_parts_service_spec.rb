# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::CombinePartsService do
  subject(:result) { described_class.call(data_export:) }

  let(:data_export) { create :data_export, :processing, resource_type: "invoice_fees" }
  let(:data_export_part) { create :data_export_part, data_export:, csv_lines:, index: 1 }
  let(:csv_lines) do
    <<~CSV
      292ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{:models=>""model_1""}",ff6c279c-9f6c-4962-987e-270936d52310,all_charges,2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
    CSV
  end

  before do
    data_export_part
  end

  describe "#call" do
    context "when there is only 1 part" do
      it "adds the correct headers" do
        expected_csv = <<~CSV
          invoice_lago_id,invoice_number,invoice_issuing_date,fee_lago_id,fee_item_type,fee_item_code,fee_item_name,fee_item_description,fee_item_invoice_display_name,fee_item_filter_invoice_display_name,fee_item_grouped_by,subscription_external_id,subscription_plan_code,fee_from_date_utc,fee_to_date_utc,fee_amount_currency,fee_units,fee_precise_unit_amount,fee_taxes_amount_cents,fee_total_amount_cents
          292ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{:models=>""model_1""}",ff6c279c-9f6c-4962-987e-270936d52310,all_charges,2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
        CSV

        expect(result).to be_success

        # deal with encoding (using download would use 8-bit ASCII)
        content = nil
        data_export.file.open do |file|
          content = File.read file
        end
        expect(content).to eq(expected_csv)
      end

      it "marks the export as complete" do
        expect(result.data_export).to be_completed
      end

      it "sends an email" do
        expect { result }
          .to have_enqueued_mail(DataExportMailer, :completed)
          .with(params: {data_export:}, args: [])
      end
    end

    context "when there are multiple parts" do
      let(:data_export_part2) { create :data_export_part, data_export:, csv_lines: csv_lines2, index: 2 }
      let(:csv_lines2) do
        <<~CSV
          392ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{:models=>""model_1""}",ff6c279c-9f6c-4962-987e-270936d52310,all_charges,2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
        CSV
      end

      before { data_export_part2 }

      it "combines the parts into 1 file in the right order" do
        expected_csv = <<~CSV
          invoice_lago_id,invoice_number,invoice_issuing_date,fee_lago_id,fee_item_type,fee_item_code,fee_item_name,fee_item_description,fee_item_invoice_display_name,fee_item_filter_invoice_display_name,fee_item_grouped_by,subscription_external_id,subscription_plan_code,fee_from_date_utc,fee_to_date_utc,fee_amount_currency,fee_units,fee_precise_unit_amount,fee_taxes_amount_cents,fee_total_amount_cents
          292ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{:models=>""model_1""}",ff6c279c-9f6c-4962-987e-270936d52310,all_charges,2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
          392ef60b-9e0c-42e7-9f50-44d5af4162ec,TWI-2B86-170-001,2024-06-06,cc16e6d5-b5e1-4e2c-9ad3-62b3ee4be302,charge,group,group,charge 1 description,group,Converted to EUR,"{:models=>""model_1""}",ff6c279c-9f6c-4962-987e-270936d52310,all_charges,2024-05-08T00:00:00+00:00,2024-06-06T12:48:59+00:00,USD,100.0,10.0,50,10000
        CSV

        expect(result).to be_success

        content = nil
        data_export.file.open do |file|
          content = File.read file
        end
        expect(content).to eq(expected_csv)
      end
    end
  end
end
