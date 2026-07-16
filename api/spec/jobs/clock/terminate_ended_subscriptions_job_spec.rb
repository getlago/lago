# frozen_string_literal: true

require "rails_helper"

describe Clock::TerminateEndedSubscriptionsJob, job: true do
  subject { described_class }

  let(:ending_at) { (Time.current + 2.months).beginning_of_day }
  let!(:subscription1) { create(:subscription, ending_at:) }
  let!(:subscription2) { create(:subscription, ending_at: ending_at + 1.year) }
  let!(:subscription3) { create(:subscription, ending_at: nil) }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    it "enqueues a TerminateEndedSubscriptionJob for matching subscriptions" do
      current_date = Time.current + 2.months

      travel_to(current_date) do
        described_class.perform_now

        expect(Subscriptions::TerminateEndedSubscriptionJob)
          .to have_been_enqueued.with(subscription1)
        expect(Subscriptions::TerminateEndedSubscriptionJob)
          .not_to have_been_enqueued.with(subscription2)
        expect(Subscriptions::TerminateEndedSubscriptionJob)
          .not_to have_been_enqueued.with(subscription3)
      end
    end

    context "with customer timezone" do
      let(:ending_at) { DateTime.parse("2022-10-21 00:30:00") }

      before do
        subscription1.customer.update!(timezone: "America/New_York")
      end

      it "takes timezone into account" do
        current_date = ending_at

        travel_to(current_date) do
          described_class.perform_now

          expect(Subscriptions::TerminateEndedSubscriptionJob)
            .to have_been_enqueued.with(subscription1)
          expect(Subscriptions::TerminateEndedSubscriptionJob)
            .not_to have_been_enqueued.with(subscription2)
          expect(Subscriptions::TerminateEndedSubscriptionJob)
            .not_to have_been_enqueued.with(subscription3)
        end
      end
    end
  end
end
