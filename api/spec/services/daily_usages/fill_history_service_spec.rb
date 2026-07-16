# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::FillHistoryService do
  let(:service) { described_class.new(subscription:, from_date:, to_date:) }

  describe "#call" do
    subject(:call_service) { service.call }

    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:customer) { create(:customer, organization:, billing_entity:) }
    let(:plan) { create(:plan, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:subscription_started_at) { Time.zone.parse("2024-10-01 00:00:00") }
    let(:subscription) do
      create(
        :subscription,
        :calendar,
        customer:,
        plan:,
        started_at: subscription_started_at,
        subscription_at: subscription_started_at
      )
    end
    let(:from_date) { Date.parse("2024-10-15") }
    let(:to_date) { Date.parse("2024-10-15") }

    context "when the only consumed charge is free (zero amount)" do
      before do
        create(:standard_charge, plan:, billable_metric:, properties: {amount: "0"})
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-15 10:00:00"),
          created_at: Time.zone.parse("2024-10-15 10:00:00")
        )
      end

      it "creates a daily usage based on consumed units" do
        travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
          expect { call_service }.to change(DailyUsage, :count).by(1)

          daily_usage = DailyUsage.order(created_at: :asc).last
          expect(daily_usage).to have_attributes(
            organization_id: organization.id,
            customer_id: customer.id,
            subscription_id: subscription.id,
            usage_date: Date.parse("2024-10-15")
          )
          expect(daily_usage.usage["amount_cents"]).to eq(0)
          expect(daily_usage.usage["charges_usage"].count).to eq(1)
        end
      end
    end

    context "when there is no usage at all" do
      before { create(:standard_charge, plan:, billable_metric:) }

      it "does not create a daily usage" do
        travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
          expect { call_service }.not_to change(DailyUsage, :count)
        end
      end
    end

    context "when only some dates in the range received events" do
      let(:from_date) { Date.parse("2024-10-14") }
      let(:to_date) { Date.parse("2024-10-16") }

      before do
        create(:standard_charge, plan:, billable_metric:, properties: {amount: "1"})
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-14 10:00:00"),
          created_at: Time.zone.parse("2024-10-14 10:00:00")
        )
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-16 10:00:00"),
          created_at: Time.zone.parse("2024-10-16 10:00:00")
        )
      end

      it "only creates daily usages for dates that received events" do
        travel_to(Time.zone.parse("2024-10-17 12:00:00")) do
          expect { call_service }.to change(DailyUsage, :count).by(2)
        end

        expect(DailyUsage.pluck(:usage_date))
          .to match_array([Date.parse("2024-10-14"), Date.parse("2024-10-16")])
      end
    end

    context "when no date in the range received events" do
      before { create(:standard_charge, plan:, billable_metric:, properties: {amount: "1"}) }

      it "does not create any daily usage" do
        travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
          expect { call_service }.not_to change(DailyUsage, :count)
        end
      end
    end

    context "when the plan has a prorated charge" do
      let(:from_date) { Date.parse("2024-10-14") }
      let(:to_date) { Date.parse("2024-10-15") }
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:) }

      before do
        create(:standard_charge, plan:, billable_metric:, prorated: true, properties: {amount: "1"})
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-14 10:00:00"),
          created_at: Time.zone.parse("2024-10-14 10:00:00"),
          properties: {"item_id" => 1}
        )
      end

      it "creates a daily usage even on dates without events" do
        travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
          expect { call_service }.to change(DailyUsage, :count).by(2)
        end

        expect(DailyUsage.pluck(:usage_date))
          .to match_array([Date.parse("2024-10-14"), Date.parse("2024-10-15")])
      end
    end

    context "when the plan has a recurring billable metric" do
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:) }

      before { create(:standard_charge, plan:, billable_metric:, properties: {amount: "1"}) }

      context "when the range stays within a single billing period" do
        let(:from_date) { Date.parse("2024-10-14") }
        let(:to_date) { Date.parse("2024-10-15") }

        before do
          create(
            :event,
            organization:,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2024-10-14 10:00:00"),
            created_at: Time.zone.parse("2024-10-14 10:00:00"),
            properties: {"item_id" => 1}
          )
        end

        it "does not force a daily usage on event-less days" do
          travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
            expect { call_service }.to change(DailyUsage, :count).by(1)
          end

          expect(DailyUsage.pluck(:usage_date)).to eq([Date.parse("2024-10-14")])
        end
      end

      context "when the range crosses a billing period boundary" do
        let(:from_date) { Date.parse("2024-10-30") }
        let(:to_date) { Date.parse("2024-11-02") }

        before do
          create(
            :event,
            organization:,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2024-10-30 10:00:00"),
            created_at: Time.zone.parse("2024-10-30 10:00:00"),
            properties: {"item_id" => 1}
          )
        end

        it "forces a daily usage on the first day of the new period only" do
          travel_to(Time.zone.parse("2024-11-03 12:00:00")) do
            expect { call_service }.to change(DailyUsage, :count).by(2)
          end

          expect(DailyUsage.pluck(:usage_date))
            .to match_array([Date.parse("2024-10-30"), Date.parse("2024-11-01")])
        end
      end
    end

    context "when the plan has a weighted sum billable metric" do
      let(:from_date) { Date.parse("2024-10-14") }
      let(:to_date) { Date.parse("2024-10-15") }
      let(:billable_metric) { create(:weighted_sum_billable_metric, organization:) }

      before do
        create(:standard_charge, plan:, billable_metric:, properties: {amount: "1"})
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-14 10:00:00"),
          created_at: Time.zone.parse("2024-10-14 10:00:00"),
          properties: {"value" => 1}
        )
      end

      it "creates a daily usage even on dates without events" do
        travel_to(Time.zone.parse("2024-10-16 12:00:00")) do
          expect { call_service }.to change(DailyUsage, :count).by(2)
        end

        expect(DailyUsage.pluck(:usage_date))
          .to match_array([Date.parse("2024-10-14"), Date.parse("2024-10-15")])
      end
    end

    context "when an existing daily_usage covers a date in the middle of the range" do
      let(:from_date) { Date.parse("2024-10-14") }
      let(:to_date) { Date.parse("2024-10-16") }
      let(:existing_daily_usage) do
        create(
          :daily_usage,
          organization:,
          customer:,
          subscription:,
          external_subscription_id: subscription.external_id,
          usage_date: Date.parse("2024-10-15"),
          from_datetime: Time.zone.parse("2024-10-01 00:00:00"),
          to_datetime: Time.zone.parse("2024-10-31 23:59:59.999999"),
          usage: {"amount_cents" => 0, "taxes_amount_cents" => 0, "total_amount_cents" => 0, "charges_usage" => []}
        )
      end

      before do
        create(:standard_charge, plan:, billable_metric:)
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-14 10:00:00"),
          created_at: Time.zone.parse("2024-10-14 10:00:00")
        )
        create(
          :event,
          organization:,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2024-10-16 10:00:00"),
          created_at: Time.zone.parse("2024-10-16 10:00:00")
        )
        existing_daily_usage
      end

      it "uses the existing daily_usage as the baseline for the next iteration's diff" do
        allow(DailyUsages::ComputeDiffService).to receive(:call).and_call_original

        travel_to(Time.zone.parse("2024-10-17 12:00:00")) { call_service }

        expect(DailyUsages::ComputeDiffService).to have_received(:call)
          .with(hash_including(previous_daily_usage: existing_daily_usage))
      end

      it "does not overwrite the existing daily_usage" do
        travel_to(Time.zone.parse("2024-10-17 12:00:00")) do
          expect { call_service }.to change(DailyUsage, :count).by(2)
        end
        expect(DailyUsage.find_by(usage_date: Date.parse("2024-10-15"))).to eq(existing_daily_usage)
      end
    end
  end

  describe "#to" do
    subject(:to) { service.to }

    let(:subscription) { create(:subscription, started_at: Time.current - 1.month) }
    let(:from_date) { Time.zone.today - 2.weeks }
    let(:to_date) { nil }

    context "when subscription is terminated" do
      before { Subscriptions::TerminateService.call(subscription:) }

      let(:to_date) { Time.zone.today + 1.week }

      it "returns the terminated_at date" do
        expect(subject).to eq(subscription.terminated_at.to_date)
      end
    end

    context "when subscription is active" do
      context "when to_date is provided" do
        let(:to_date) { Time.zone.today + 1.week }

        it "returns the to_date date" do
          expect(subject).to eq(to_date)
        end
      end

      context "when to_date is nil" do
        it "returns yesterday" do
          expect(subject).to eq(Time.zone.yesterday)
        end
      end
    end
  end
end
