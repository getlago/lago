# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::ProcessJob do
  subject(:process_job) { described_class }

  let(:inbound_webhook) { create :inbound_webhook }
  let(:result) { BaseService::Result.new }

  before do
    allow(InboundWebhooks::ProcessService).to receive(:call).and_return(result)
  end

  it "calls the process webhook service" do
    process_job.perform_now(inbound_webhook:)

    expect(InboundWebhooks::ProcessService)
      .to have_received(:call)
      .with(inbound_webhook:)
  end

  context "when result is a failure" do
    let(:result) do
      BaseService::Result.new.service_failure!(code: "error", message: "error message")
    end

    it "raises an error" do
      expect { process_job.perform_now(inbound_webhook:) }
        .to raise_error(BaseService::FailedResult)
    end
  end
end
