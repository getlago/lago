# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::PostProcessJob do
  let(:result) { BaseService::Result.new }

  let(:event) do
    create(:event)
  end

  it "calls the event post process service" do
    allow(Events::PostProcessService).to receive(:call)
      .with(event:)
      .and_return(result)

    described_class.perform_now(event:)

    expect(Events::PostProcessService).to have_received(:call)
  end
end
