# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Breakdown::SumService, transaction: false do
  subject(:service) do
    described_class.new(
      event_store_class:,
      charge:,
      subscription:,
      boundaries: {
        from_datetime:,
        to_datetime:,
        charges_duration: 31
      },
      filters: {
        matching_filters:,
        ignored_filters:
      }
    )
  end

  let(:event_store_class) { Events::Stores::PostgresStore }

  let(:subscription) do
    create(
      :subscription,
      started_at:,
      subscription_at:,
      billing_time: :anniversary
    )
  end

  let(:subscription_at) { Time.zone.parse("2022-12-01 00:00:00") }
  let(:started_at) { subscription_at }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }

  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "sum_agg",
      field_name: "total_count",
      recurring: true
    )
  end

  let(:charge) do
    create(
      :standard_charge,
      billable_metric:
    )
  end

  let(:from_datetime) { Time.zone.parse("2023-05-01 00:00:00") }
  let(:to_datetime) { Time.zone.parse("2023-05-31 23:59:59") }

  let(:old_events) do
    create_list(
      :event,
      2,
      organization_id: organization.id,
      code: billable_metric.code,
      customer:,
      subscription:,
      timestamp: subscription.started_at + 3.months,
      properties: {
        total_count: 2.5
      }
    )
  end
  let(:latest_events) do
    create(
      :event,
      organization_id: organization.id,
      code: billable_metric.code,
      customer:,
      subscription:,
      timestamp: from_datetime + 25.days,
      properties: {
        total_count: 12
      }
    )
  end

  before do
    old_events
    latest_events
  end

  describe "#breakdown" do
    let(:result) { service.breakdown.breakdown }

    context "with persisted metric on full period" do
      it "returns the detail the persisted metrics" do
        expect(result.count).to eq(2)

        item = result.first
        expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
        expect(item.action).to eq("add")
        expect(item.amount).to eq(5)
        expect(item.duration).to eq(31)
        expect(item.total_duration).to eq(31)

        item = result.last
        expect(item.date.to_s).to eq((from_datetime + 25.days).to_date.to_s)
        expect(item.action).to eq("add")
        expect(item.amount).to eq(12)
        expect(item.duration).to eq(6)
        expect(item.total_duration).to eq(31)
      end

      context "when subscription was terminated in the period" do
        let(:latest_events) { nil }
        let(:subscription) do
          create(
            :subscription,
            started_at:,
            subscription_at:,
            billing_time: :anniversary,
            terminated_at: to_datetime,
            status: :terminated
          )
        end
        let(:to_datetime) { Time.zone.parse("2023-05-30 23:59:59") }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(from_datetime.to_date.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(5)
          expect(item.duration).to eq(30)
          expect(item.total_duration).to eq(31)
        end
      end

      context "when subscription was started in the period" do
        let(:started_at) { Time.zone.parse("2023-05-03") }
        let(:old_events) { nil }
        let(:from_datetime) { started_at }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq((from_datetime + 25.days).to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(12)
          expect(item.duration).to eq(4)
          expect(item.total_duration).to eq(31)
        end
      end
    end
  end
end
