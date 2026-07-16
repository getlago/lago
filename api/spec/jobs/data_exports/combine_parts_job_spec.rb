# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::CombinePartsJob do
  let(:data_export) { create(:data_export) }
  let(:result) { BaseService::Result.new }

  before do
    allow(DataExports::CombinePartsService)
      .to receive(:call)
      .with(data_export:)
      .and_return(result)
  end

  it "calls ProcessPart service" do
    described_class.perform_now(data_export)

    expect(DataExports::CombinePartsService)
      .to have_received(:call)
      .with(data_export:)
  end
end
