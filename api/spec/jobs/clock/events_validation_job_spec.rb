# frozen_string_literal: true

require "rails_helper"

describe Clock::EventsValidationJob, job: true, transaction: false do
  subject { described_class }

  let(:organization) { create(:organization) }
  let(:event) do
    create(
      :event,
      organization:,
      created_at: Time.current.beginning_of_hour - 25.minutes
    )
  end

  describe ".perform" do
    before { event }

    it "refresh the events materialized view" do
      described_class.perform_now

      expect(Events::LastHourMv.count).to eq(1)
    end

    it "enqueues job for post validation" do
      described_class.perform_now

      expect(Events::PostValidationJob).to have_been_enqueued
        .with(organization:)
    end

    context "when organization does not have webhook endpoints" do
      before { organization.webhook_endpoints.destroy_all }

      it "does not enqueue a job" do
        described_class.perform_now

        expect(Events::PostValidationJob).not_to have_been_enqueued
          .with(organization:)
      end
    end
  end
end
