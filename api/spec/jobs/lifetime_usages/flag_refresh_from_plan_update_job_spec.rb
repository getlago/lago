# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::FlagRefreshFromPlanUpdateJob do
  let(:plan) { create(:plan) }

  it "delegates to the FlagRefreshFromPlanUpdate service" do
    allow(LifetimeUsages::FlagRefreshFromPlanUpdateService).to receive(:call)
    described_class.perform_now(plan)
    expect(LifetimeUsages::FlagRefreshFromPlanUpdateService).to have_received(:call).with(plan:)
  end
end
