# frozen_string_literal: true

require "rails_helper"

require_relative "shared_examples/an_event_store"

RSpec.describe Events::Stores::ClickhouseEnrichedStore, clickhouse: {clean_before: true} do
  def create_event(timestamp:, value:, properties: {}, transaction_id: SecureRandom.uuid, code: billable_metric.code, charge_filter: nil, enriched_at: nil, event_charge: nil, created_at: nil)
    effective_charge = event_charge || charge

    grouped_values = if events_grouped_by.present?
      events_grouped_by.index_with({}) { properties[it] || "" }
    end

    Clickhouse::EventsEnrichedExpanded.create!(
      transaction_id:,
      organization_id: organization.id,
      external_subscription_id: subscription.external_id,
      subscription_id: subscription.id,
      plan_id: subscription.plan_id,
      code:,
      aggregation_type: billable_metric.aggregation_type,
      charge_id: effective_charge.id,
      charge_version: effective_charge.updated_at,
      charge_filter_id: charge_filter&.id || "",
      charge_filter_version: charge_filter&.updated_at,
      timestamp:,
      properties: properties.merge(billable_metric.field_name => value).compact,
      grouped_by: grouped_values,
      value:,
      decimal_value: value&.to_i&.to_d,
      precise_total_amount_cents: value,
      enriched_at: created_at || enriched_at
    )
  end

  alias_method :create_enriched_event, :create_event

  def format_timestamp(timestamp, precision: 3)
    Time.zone.parse(timestamp).strftime("%Y-%m-%d %H:%M:%S.%#{precision}L")
  end

  context "without deduplication" do
    it_behaves_like "an event store", with_event_duplication: false, excluding_features: [:distinct_codes_and_property_combinations]
  end

  context "with deduplication" do
    it_behaves_like "an event store", with_event_duplication: true, excluding_features: [:distinct_codes_and_property_combinations]
  end

  describe "#grouped_arel_columns" do
    subject(:event_store) do
      described_class.new(
        code: billable_metric.code,
        subscription:,
        boundaries:,
        filters: {
          grouped_by:,
          presentation_by:
        }
      )
    end

    let(:billable_metric) { create(:billable_metric, field_name: "value", code: "bm:code") }
    let(:organization) { billable_metric.organization }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:boundaries) do
      {
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 31
      }
    end

    context "when presentation_by is not included in grouped_by" do
      let(:grouped_by) { ["cloud"] }
      let(:presentation_by) { ["agent_name"] }

      it "returns the precomputed sorted grouped by column" do
        columns, names = event_store.grouped_arel_columns

        expect(columns.count).to eq(1)
        expect(columns.first.left.name).to eq("sorted_grouped_by")
        expect(columns.first.right).to eq("grouped_by")
        expect(names).to eq(["grouped_by"])
      end
    end

    context "when presentation_by is included in grouped_by" do
      let(:grouped_by) { ["cloud", "agent_name"] }
      let(:presentation_by) { ["cloud"] }

      it "returns a mapped grouped_by from the grouped properties" do
        columns, names = event_store.grouped_arel_columns

        expect(columns.count).to eq(1)
        expect(columns.first.left.to_s).to eq("map('agent_name', sorted_properties['agent_name'], 'cloud', sorted_properties['cloud'])")
        expect(columns.first.right.to_s).to eq("grouped_by")
        expect(names).to eq(["grouped_by"])
      end
    end

    context "when the store is duplicated with another grouped_by" do
      let(:grouped_by) { ["cloud"] }
      let(:presentation_by) { ["agent_name"] }

      it "builds the mapped grouped_by from the duplicated grouped_by" do
        duplicated_store = event_store.dup
        duplicated_store.grouped_by = ["agent_name", "cloud"]

        columns, names = duplicated_store.grouped_arel_columns

        expect(event_store.grouped_by).to eq(["cloud"])
        expect(columns.count).to eq(1)
        expect(columns.first.left.to_s).to eq("map('agent_name', sorted_properties['agent_name'], 'cloud', sorted_properties['cloud'])")
        expect(columns.first.right.to_s).to eq("grouped_by")
        expect(names).to eq(["grouped_by"])
      end
    end
  end
end
