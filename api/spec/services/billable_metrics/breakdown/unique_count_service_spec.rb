# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Breakdown::UniqueCountService, transaction: false do
  subject(:service) do
    described_class.new(
      event_store_class:,
      charge:,
      subscription:,
      boundaries: {
        from_datetime:,
        to_datetime:,
        charges_duration: (to_datetime - from_datetime).fdiv(1.day).round
      },
      filters: {
        matching_filters:,
        ignored_filters:
      }
    )
  end

  let(:event_store_class) { Events::Stores::PostgresStore }

  let(:organization) { create(:organization) }

  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "unique_count_agg",
      field_name: "unique_id",
      recurring: true
    )
  end

  let(:plan) do
    create(
      :plan,
      organization:
    )
  end

  let(:charge) do
    create(
      :standard_charge,
      plan:,
      billable_metric:
    )
  end

  let(:subscription) do
    create(
      :subscription,
      organization:,
      plan:,
      started_at:,
      subscription_at:,
      billing_time: :anniversary
    )
  end

  let(:subscription_at) { Time.zone.parse("2022-06-09") }
  let(:started_at) { subscription_at }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }

  let(:from_datetime) { Time.zone.parse("2022-07-09 00:00:00 UTC") }
  let(:to_datetime) { Time.zone.parse("2022-08-08 23:59:59 UTC") }

  let(:added_at) { from_datetime - 1.month }
  let(:removed_at) { nil }
  let(:added_event) do
    create(
      :event,
      organization_id: organization.id,
      timestamp: added_at,
      external_subscription_id: subscription.external_id,
      code: billable_metric.code,
      properties: {unique_id: "111"}
    )
  end

  let(:removed_event) do
    next nil unless removed_at

    create(
      :event,
      organization_id: organization.id,
      timestamp: removed_at,
      external_subscription_id: subscription.external_id,
      code: billable_metric.code,
      properties: {unique_id: "111", operation_type: "remove"}
    )
  end

  before do
    added_event
    removed_event
  end

  describe "#breakdown" do
    let(:result) { service.breakdown.breakdown }

    context "with persisted metric on full period" do
      it "returns the detail the persisted metrics" do
        expect(result.count).to eq(1)

        item = result.first
        expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
        expect(item.action).to eq("add")
        expect(item.amount).to eq(1)
        expect(item.duration).to eq(31)
        expect(item.total_duration).to eq(31)
      end

      context "when subscription was terminated in the period" do
        let(:subscription) do
          create(
            :subscription,
            organization:,
            plan:,
            started_at:,
            subscription_at:,
            billing_time: :anniversary,
            terminated_at: to_datetime,
            status: :terminated
          )
        end
        let(:to_datetime) { Time.zone.parse("2022-07-24 23:59:59") }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(from_datetime.to_date.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(16)
          expect(item.total_duration).to eq(16)
        end
      end

      context "when subscription was upgraded in the period" do
        let(:subscription) do
          create(
            :subscription,
            organization:,
            started_at:,
            subscription_at:,
            billing_time: :anniversary,
            terminated_at: to_datetime,
            status: :terminated
          )
        end
        let(:to_datetime) { Time.zone.parse("2022-07-24 23:59:59") }

        before do
          create(
            :subscription,
            previous_subscription: subscription,
            organization:,
            plan:,
            started_at: to_datetime
          )
        end

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(16)
          expect(item.total_duration).to eq(16)
        end

        context "with calendar subscription and pay in advance" do
          let(:subscription) do
            create(
              :subscription,
              organization:,
              plan:,
              started_at:,
              subscription_at:,
              billing_time: :calendar,
              terminated_at: to_datetime,
              status: :terminated
            )
          end

          before { subscription.plan.update!(pay_in_advance: true) }

          it "returns the detail the persisted metrics" do
            expect(result.count).to eq(1)

            item = result.first
            expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
            expect(item.action).to eq("add")
            expect(item.amount).to eq(1)
            expect(item.duration).to eq(16)
            expect(item.total_duration).to eq(16)
          end
        end
      end

      context "when subscription was started in the period" do
        let(:started_at) { Time.zone.parse("2022-08-01") }
        let(:from_datetime) { started_at }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(8)
          expect(item.total_duration).to eq(8)
        end
      end
    end

    context "with persisted metrics added in the period" do
      let(:added_at) { from_datetime + 15.days }

      it "returns the detail the persisted metrics" do
        expect(result.count).to eq(1)

        item = result.first
        expect(item.date.to_s).to eq(added_at.to_date.to_s)
        expect(item.action).to eq("add")
        expect(item.amount).to eq(1)
        expect(item.duration).to eq(16)
        expect(item.total_duration).to eq(31)
      end

      context "when added on the first day of the period" do
        let(:added_at) { from_datetime }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(from_datetime.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(31)
          expect(item.total_duration).to eq(31)
        end
      end
    end

    context "with persisted metrics terminated in the period" do
      let(:removed_at) { to_datetime - 15.days }

      it "returns the detail the persisted metrics" do
        expect(result.count).to eq(1)

        item = result.first
        expect(item.date.to_s).to eq(removed_at.to_date.to_s)
        expect(item.action).to eq("remove")
        expect(item.amount).to eq(1)
        expect(item.duration).to eq(16)
        expect(item.total_duration).to eq(31)
      end

      context "when removed on the last day of the period" do
        let(:removed_at) { to_datetime }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(to_datetime.to_date.to_s)
          expect(item.action).to eq("remove")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(31)
          expect(item.total_duration).to eq(31)
        end
      end
    end

    context "with persisted metrics added and terminated in the period" do
      let(:added_at) { from_datetime + 1.day }
      let(:removed_at) { to_datetime - 1.day }

      it "returns the detail the persisted metrics" do
        expect(result.count).to eq(1)

        item = result.first
        expect(item.date.to_s).to eq(added_at.to_date.to_s)
        expect(item.action).to eq("add_and_removed")
        expect(item.amount).to eq(1)
        expect(item.duration).to eq(29)
        expect(item.total_duration).to eq(31)
      end

      context "when added and removed the same day" do
        let(:added_at) { from_datetime + 1.day }
        let(:removed_at) { added_at.end_of_day }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(added_at.to_date.to_s)
          expect(item.action).to eq("add_and_removed")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(1)
          expect(item.total_duration).to eq(31)
        end
      end

      context "when added, removed and added again" do
        let(:added_at) { from_datetime + 1.day }
        let(:removed_at) { added_at.end_of_day }
        let(:new_event) do
          create(
            :event,
            organization_id: organization.id,
            timestamp: to_datetime - 1.day,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {unique_id: "111"}
          )
        end

        before { new_event }

        it "returns the detail the persisted metrics" do
          expect(result.count).to eq(1)

          item = result.first
          expect(item.date.to_s).to eq(added_at.to_date.to_s)
          expect(item.action).to eq("add")
          expect(item.amount).to eq(1)
          expect(item.duration).to eq(3)
          expect(item.total_duration).to eq(31)
        end
      end
    end
  end
end
