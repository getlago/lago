# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Adyen::HandleEventJob do
  subject(:handle_event_job) { described_class }

  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:event_json) { "{}" }

  before do
    allow(PaymentProviders::Adyen::HandleEventService).to receive(:call!)
      .and_return(result)
  end

  it "calls the handle event service" do
    described_class.perform_now(organization:, event_json:)

    expect(PaymentProviders::Adyen::HandleEventService).to have_received(:call!)
  end
end
