# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::TerminateJob do
  let(:subscription) { create(:subscription) }
  let(:timestamp) { Time.zone.now.to_i }

  let(:subscription_service) { instance_double(Subscriptions::TerminateService) }
  let(:result) { BaseService::Result.new }

  it "calls the subscription service" do
    allow(Subscriptions::TerminateService).to receive(:new)
      .with(subscription:)
      .and_return(subscription_service)
    allow(subscription_service).to receive(:terminate_and_start_next)
      .with(timestamp:)
      .and_return(result)

    described_class.perform_now(subscription, timestamp)

    expect(Subscriptions::TerminateService).to have_received(:new)
    expect(subscription_service).to have_received(:terminate_and_start_next)
  end

  context "when result is a failure" do
    let(:result) do
      BaseService::Result.new.not_found_failure!(resource: "subscription")
    end

    it "raises an error" do
      allow(Subscriptions::TerminateService).to receive(:new)
        .with(subscription:)
        .and_return(subscription_service)
      allow(subscription_service).to receive(:terminate_and_start_next)
        .with(timestamp:)
        .and_return(result)

      expect do
        described_class.perform_now(subscription, timestamp)
      end.to raise_error(BaseService::FailedResult)

      expect(Subscriptions::TerminateService).to have_received(:new)
      expect(subscription_service).to have_received(:terminate_and_start_next)
    end
  end
end
