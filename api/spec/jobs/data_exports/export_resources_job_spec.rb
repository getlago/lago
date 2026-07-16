# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::ExportResourcesJob do
  let(:data_export) { create(:data_export) }
  let(:result) { BaseService::Result.new }

  before do
    allow(DataExports::ExportResourcesService)
      .to receive(:call)
      .with(data_export:, batch_size: 20)
      .and_return(result)
  end

  it "calls ExportResources service" do
    described_class.perform_now(data_export)

    expect(DataExports::ExportResourcesService)
      .to have_received(:call)
      .with(data_export:, batch_size: 20)
  end
end
