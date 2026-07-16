# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::CreatePartService do
  subject(:result) { described_class.call(data_export:, object_ids:, index:) }

  let(:data_export) { create :data_export, resource_type: "invoices", format: "csv" }

  let(:index) { 1 }
  let(:object_ids) { [uuid] }
  let(:uuid) { SecureRandom.uuid }

  it "creates 1 part" do
    expect { result }.to change(DataExportPart, :count).by(1)
    expect(result).to be_success
    expect(result.data_export_part.index).to eq(index)
    expect(result.data_export_part.object_ids).to eq(object_ids)
    expect(data_export.reload.data_export_parts.sole).to eq(result.data_export_part)
  end

  it "enqueues a job for this part" do
    expect { result }.to have_enqueued_job(DataExports::ProcessPartJob).on_queue("default")
  end
end
