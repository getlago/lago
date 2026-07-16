# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::PayInAdvanceJob do
  let(:pay_in_advance_service) { instance_double(Events::PayInAdvanceService) }
  let(:result) { BaseService::Result.new }

  let(:event) { build(:common_event) }

  it "calls the event pay in advance service" do
    allow(Events::PayInAdvanceService).to receive(:call)
      .with(event:)
      .and_return(result)

    described_class.perform_now(event)

    expect(Events::PayInAdvanceService).to have_received(:call)
  end
end
