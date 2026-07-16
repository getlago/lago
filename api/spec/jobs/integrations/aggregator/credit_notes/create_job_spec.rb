# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::CreditNotes::CreateJob do
  subject(:create_job) { described_class }

  let(:credit_note) { create(:credit_note) }
  let(:result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::CreditNotes::CreateService).to receive(:call).and_return(result)
  end

  it "calls the aggregator create credit_note service" do
    described_class.perform_now(credit_note:)

    expect(Integrations::Aggregator::CreditNotes::CreateService).to have_received(:call)
  end
end
