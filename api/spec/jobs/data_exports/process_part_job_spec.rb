# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::ProcessPartJob do
  let(:data_export_part) { create(:data_export_part) }
  let(:result) { BaseService::Result.new }

  before do
    allow(DataExports::ProcessPartService)
      .to receive(:call)
      .with(data_export_part:)
      .and_return(result)
  end

  it "calls ProcessPart service" do
    described_class.perform_now(data_export_part)

    expect(DataExports::ProcessPartService)
      .to have_received(:call)
      .with(data_export_part:)
  end
end
