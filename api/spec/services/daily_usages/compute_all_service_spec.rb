# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::ComputeAllService do
  subject(:compute_service) { described_class.new(timestamp:) }

  let(:timestamp) { Time.zone.parse("2024-10-22 00:05:00") }

  let(:organization) { create(:organization, premium_integrations:) }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:subscriptions) { create_list(:subscription, 5, customer:, last_received_event_on: timestamp.to_date - 1.day) }

  let(:premium_integrations) do
    ["revenue_analytics"]
  end

  before { subscriptions }

  describe "#call" do
    it "enqueues a job to compute the daily usage" do
      expect(compute_service.call).to be_success
      subscriptions.each do |subscription|
        expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
      end
    end

    context "when LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS is set" do
      before { stub_const("ENV", ENV.to_h.merge("LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS" => "60")) }

      it "uses the configured interval" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.seconds.from_now, 60.seconds.from_now))
        end
      end
    end

    context "when LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS is negative" do
      before { stub_const("ENV", ENV.to_h.merge("LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS" => "-100")) }

      it "falls back to the default interval" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
        end
      end
    end

    context "when LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS is zero" do
      before { stub_const("ENV", ENV.to_h.merge("LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS" => "0")) }

      it "falls back to the default interval" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
        end
      end
    end

    context "when LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS is non-numeric" do
      before { stub_const("ENV", ENV.to_h.merge("LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS" => "invalid")) }

      it "falls back to the default interval" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
        end
      end
    end

    context "when LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS is blank" do
      before { stub_const("ENV", ENV.to_h.merge("LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS" => "")) }

      it "falls back to the default interval" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
        end
      end
    end

    context "when subscription usage was already computed" do
      before { create(:daily_usage, subscription: subscriptions.first, customer: subscriptions.first.customer, usage_date: timestamp.to_date - 1.day) }

      it "does not enqueue any job" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued.with(subscriptions.first, timestamp:)
        subscriptions[1..].each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:).at(a_value_between(0.minutes.from_now, 30.minutes.from_now))
        end
      end
    end

    context "when the organization has a timezone" do
      let(:organization) { create(:organization, timezone: "America/Sao_Paulo", premium_integrations:) }

      before do
        billing_entity.update(timezone: "America/Sao_Paulo")
      end

      it "takes the timezone into account" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end

      context "when the day starts in the timezone" do
        let(:timestamp) { Time.zone.parse("2024-10-22 03:05:00") }

        it "enqueues a job to compute the daily usage" do
          expect(compute_service.call).to be_success
          subscriptions.each do |subscription|
            expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
          end
        end
      end
    end

    context "when the customer has a timezone" do
      let(:customer) { create(:customer, organization:, timezone: "America/Sao_Paulo") }

      it "takes the timezone into account" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end

      context "when the day starts in the timezone" do
        let(:timestamp) { Time.zone.parse("2024-10-22 03:05:00") }

        it "enqueues a job to compute the daily usage" do
          expect(compute_service.call).to be_success
          subscriptions.each do |subscription|
            expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
          end
        end
      end
    end

    context "when last_received_event_on is nil" do
      let(:subscriptions) { create_list(:subscription, 5, customer:, last_received_event_on: nil) }

      it "does not enqueue any job" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end
    end

    context "when last_received_event_on is today" do
      let(:subscriptions) { create_list(:subscription, 5, customer:, last_received_event_on: timestamp.to_date) }

      it "does enqueue jobs" do
        expect(compute_service.call).to be_success
        subscriptions.each do |subscription|
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
        end
      end
    end

    context "when last_received_event_on is stale" do
      let(:subscriptions) { create_list(:subscription, 5, customer:, last_received_event_on: timestamp.to_date - 5.days) }

      it "does not enqueue any job" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end
    end

    context "when the subscription has time-dependent usage but no recent events" do
      let(:plan) { create(:plan, organization:) }
      let(:billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
      let(:subscriptions) do
        create_list(:subscription, 5, customer:, plan:, last_received_event_on: timestamp.to_date - 5.days)
      end

      context "with a prorated charge" do
        before { create(:standard_charge, plan:, billable_metric:, prorated: true) }

        it "enqueues jobs even though no event was received" do
          expect(compute_service.call).to be_success
          subscriptions.each do |subscription|
            expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
          end
        end
      end

      context "with a recurring billable metric" do
        # Recurring metrics are constant between events, so they are recomputed once per period,
        # on the run following the period rollover (timestamp - 1.day). With a calendar monthly
        # plan, that rollover is the 1st of the month.
        let(:timestamp) { Time.zone.parse("2024-10-02 00:05:00") }
        let(:subscriptions) do
          create_list(:subscription, 5, :calendar, customer:, plan:, last_received_event_on: timestamp.to_date - 5.days)
        end

        before { create(:standard_charge, plan:, billable_metric:) }

        it "enqueues jobs on the run following the period rollover" do
          expect(compute_service.call).to be_success
          subscriptions.each do |subscription|
            expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
          end
        end

        context "when no period rolled over the previous day" do
          let(:timestamp) { Time.zone.parse("2024-10-22 00:05:00") }

          it "does not enqueue any job" do
            expect(compute_service.call).to be_success
            expect(DailyUsages::ComputeJob).not_to have_been_enqueued
          end
        end
      end

      context "with a weighted_sum aggregation" do
        let(:billable_metric) { create(:weighted_sum_billable_metric, organization:) }

        before { create(:standard_charge, plan:, billable_metric:) }

        it "enqueues jobs even though no event was received" do
          expect(compute_service.call).to be_success
          subscriptions.each do |subscription|
            expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscription, timestamp:)
          end
        end
      end

      context "with a charge that is not time-dependent" do
        let(:billable_metric) { create(:billable_metric, organization:, recurring: false) }

        before { create(:standard_charge, plan:, billable_metric:) }

        it "does not enqueue any job" do
          expect(compute_service.call).to be_success
          expect(DailyUsages::ComputeJob).not_to have_been_enqueued
        end
      end

      context "with a deleted recurring charge" do
        before { create(:standard_charge, plan:, billable_metric:, deleted_at: timestamp) }

        it "does not enqueue any job" do
          expect(compute_service.call).to be_success
          expect(DailyUsages::ComputeJob).not_to have_been_enqueued
        end
      end
    end

    context "when leg conditions overlap" do
      let(:plan) { create(:plan, organization:) }

      context "when a recurring subscription received a recent event off its rollover day" do
        # 2024-10-22 is not a rollover for a calendar monthly plan, but the recent event keeps the
        # subscription in the daily (event) leg — active recurring subs are not starved off-rollover.
        let(:billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
        let(:subscriptions) do
          create_list(:subscription, 1, :calendar, customer:, plan:, last_received_event_on: timestamp.to_date)
        end

        before { create(:standard_charge, plan:, billable_metric:) }

        it "still enqueues a job via the event leg" do
          expect(compute_service.call).to be_success
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscriptions.first, timestamp:)
        end
      end

      context "when a subscription matches both the time-dependent and recurring legs" do
        # A prorated charge on a recurring metric puts the plan in both the time-dependent leg
        # (prorated) and the recurring leg (recurring metric). With no recent event, on its rollover
        # day, the subscription matches both — the Set union must enqueue it only once.
        let(:timestamp) { Time.zone.parse("2024-10-02 00:05:00") }
        let(:billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
        let(:subscriptions) do
          create_list(:subscription, 1, :calendar, customer:, plan:, last_received_event_on: timestamp.to_date - 5.days)
        end

        before { create(:standard_charge, plan:, billable_metric:, prorated: true) }

        it "enqueues the job only once" do
          expect(compute_service.call).to be_success
          expect(DailyUsages::ComputeJob).to have_been_enqueued.with(subscriptions.first, timestamp:).once
        end
      end
    end

    context "when revenue_analytics premium integration flag is not present" do
      let(:premium_integrations) { [] }

      it "does not enqueue any job" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end
    end

    context "when skip_daily_usage is true" do
      let(:subscriptions) { create_list(:subscription, 5, customer:, last_received_event_on: timestamp.to_date, skip_daily_usage: true) }

      it "does not enqueue any job" do
        expect(compute_service.call).to be_success
        expect(DailyUsages::ComputeJob).not_to have_been_enqueued
      end
    end
  end
end
