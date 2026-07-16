# frozen_string_literal: true

require "rails_helper"

require_relative "shared_examples/an_event_store"

RSpec.describe Events::Stores::PostgresStore do
  it_behaves_like "an event store", with_event_duplication: false do
    def create_event(timestamp:, value:, properties: {}, transaction_id: SecureRandom.uuid, code: billable_metric.code, charge_filter: nil, enriched_at: nil, event_charge: nil, created_at: nil)
      attributes = {
        transaction_id: transaction_id,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        external_customer_id: customer.external_id,
        code:,
        timestamp: timestamp,
        properties: properties.merge(billable_metric.field_name => value),
        precise_total_amount_cents: value
      }
      attributes[:created_at] = created_at if created_at

      create(:event, **attributes)
    end

    def create_enriched_event(timestamp:, value:, properties: {}, transaction_id: SecureRandom.uuid, code: billable_metric.code, charge_filter: nil, enriched_at: nil)
      event = create(
        :event,
        transaction_id:,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        external_customer_id: customer.external_id,
        code:,
        timestamp:,
        properties:
      )

      create(
        :enriched_event,
        subscription:,
        event:,
        charge:,
        charge_filter_id: charge_filter&.id,
        value:,
        decimal_value: value&.to_i&.to_d
      )
    end

    def format_timestamp(timestamp, precision: nil)
      Time.zone.parse(timestamp)
    end
  end

  describe "#count" do
    context "when the upper boundary is a pay-in-advance event (max_timestamp)" do
      let(:billable_metric) { create(:billable_metric) }
      let(:organization) { billable_metric.organization }
      let(:customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, customer:, started_at: DateTime.parse("2023-03-15")) }
      let(:timestamp) { subscription.started_at + 1.day }

      let(:previous_event) { create_event(timestamp: timestamp - 1.hour, created_at: timestamp - 1.hour) }
      let(:next_event) { create_event(timestamp: timestamp + 1.hour, created_at: timestamp + 1.hour) }

      def create_event(timestamp:, created_at:)
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp:,
          created_at:
        )
      end

      def store_for(event)
        described_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {
            from_datetime: subscription.started_at.beginning_of_day,
            to_datetime: subscription.started_at.end_of_month.end_of_day,
            max_timestamp: event.timestamp
          },
          filters: {event: Events::CommonFactory.new_instance(source: event)}
        )
      end

      before do
        previous_event
        next_event
      end

      it "assigns a distinct position to each event sharing the boundary timestamp" do
        tied_events = (1..3).map { |i| create_event(timestamp:, created_at: timestamp + i.seconds) }

        expect(tied_events.map { |event| store_for(event).count.value }).to eq([2, 3, 4])
      end

      it "assigns distinct positions when created_at is also tied" do
        tied_events = (1..3).map { create_event(timestamp:, created_at: timestamp) }

        expect(tied_events.map { |event| store_for(event).count.value }).to match_array([2, 3, 4])
      end

      it "counts all events sharing the timestamp when no event filter is given" do
        create_event(timestamp:, created_at: timestamp + 1.second)
        create_event(timestamp:, created_at: timestamp + 2.seconds)

        event_store = described_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {
            from_datetime: subscription.started_at.beginning_of_day,
            to_datetime: subscription.started_at.end_of_month.end_of_day,
            max_timestamp: timestamp
          },
          filters: {}
        )

        expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 3, events_count: 3))
      end
    end
  end

  describe "#weighted_sum" do
    context "when the period is zero-length and holds no event" do
      let(:billable_metric) { create(:weighted_sum_billable_metric) }
      let(:organization) { billable_metric.organization }
      let(:customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, customer:, started_at: DateTime.parse("2023-03-15")) }
      let(:datetime) { subscription.started_at.beginning_of_day }

      let(:event_store) do
        described_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {
            from_datetime: datetime,
            to_datetime: datetime,
            charges_duration: 31
          }
        )
      end

      # NOTE: from_datetime == to_datetime makes both boundary rows identical, so the UNION in the
      #       events CTE dedups them into one. events_count must not go negative.
      it "returns a zero events count" do
        result = event_store.weighted_sum

        expect(result.events_count).to eq(0)
      end
    end
  end
end
