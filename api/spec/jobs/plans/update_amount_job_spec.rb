# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::UpdateAmountJob do
  let(:plan) { create(:plan) }
  let(:amount_cents) { 200 }
  let(:expected_amount_cents) { 100 }

  before do
    allow(Plans::UpdateAmountService).to receive(:call).with(plan:, amount_cents:, expected_amount_cents:).and_call_original
  end

  it "calls the service" do
    described_class.perform_now(plan:, amount_cents:, expected_amount_cents:)

    expect(Plans::UpdateAmountService).to have_received(:call).with(plan:, amount_cents:, expected_amount_cents:)
  end
end
