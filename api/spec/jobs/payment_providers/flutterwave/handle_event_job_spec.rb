# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Flutterwave::HandleEventJob do
  subject(:handle_event_job) { described_class.new }

  let(:organization) { create(:organization) }
  let(:event_json) { {event: "charge.completed", data: {}}.to_json }

  describe "#perform" do
    it "calls the HandleEventService" do
      allow(PaymentProviders::Flutterwave::HandleEventService)
        .to receive(:call!)

      handle_event_job.perform(organization:, event: event_json)

      expect(PaymentProviders::Flutterwave::HandleEventService)
        .to have_received(:call!)
        .with(organization:, event_json: event_json)
    end
  end

  describe "queue configuration" do
    context "when SIDEKIQ_PAYMENTS is true" do
      before { ENV["SIDEKIQ_PAYMENTS"] = "true" }
      after { ENV.delete("SIDEKIQ_PAYMENTS") }

      it "uses the payments queue" do
        expect {
          described_class.perform_later(organization:, event: "test")
        }.to have_enqueued_job.on_queue("payments")
      end
    end

    context "when SIDEKIQ_PAYMENTS is false or not set" do
      before { ENV.delete("SIDEKIQ_PAYMENTS") }

      it "uses the providers queue" do
        expect {
          described_class.perform_later(organization:, event: "test")
        }.to have_enqueued_job.on_queue("providers")
      end
    end
  end
end
