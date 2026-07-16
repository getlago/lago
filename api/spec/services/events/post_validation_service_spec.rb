# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::PostValidationService, transaction: false do
  subject(:validation_service) { described_class.new(organization:) }

  let(:organization) { create(:organization) }

  let(:invalid_code_event) do
    create(
      :event,
      organization:,
      code: Faker::Name.name.underscore,
      created_at: Time.current.beginning_of_hour - 25.minutes
    )
  end

  let(:billable_metric) do
    create(
      :sum_billable_metric,
      organization:
    )
  end

  let(:missing_aggregation_property_event) do
    create(
      :event,
      organization:,
      code: billable_metric.code,
      properties: {},
      created_at: Time.current.beginning_of_hour - 25.minutes
    )
  end

  let(:negative_aggregation_property_event) do
    create(
      :event,
      organization:,
      code: billable_metric.code,
      properties: {billable_metric.field_name => -12},
      created_at: Time.current.beginning_of_hour - 25.minutes
    )
  end

  let(:billable_metric_with_filter) do
    create(
      :billable_metric,
      organization:
    )
  end

  let(:billable_metric_filter) do
    create(
      :billable_metric_filter,
      billable_metric: billable_metric_with_filter,
      key: "region",
      values: %w[eu-west-1 us-east-1]
    )
  end

  let(:invalid_filter_values_event) do
    create(
      :event,
      organization:,
      code: billable_metric_with_filter.code,
      properties: {billable_metric_filter.key => "us-west-4"},
      created_at: Time.current.beginning_of_hour - 25.minutes
    )
  end

  before do
    invalid_code_event
    missing_aggregation_property_event
    negative_aggregation_property_event
    invalid_filter_values_event

    Scenic.database.refresh_materialized_view(
      Events::LastHourMv.table_name,
      concurrently: false,
      cascade: false
    )
  end

  describe ".call" do
    context "when does not belong to the organization" do
      before { allow(SendWebhookJob).to receive(:perform_later) }

      let(:other_organization) { create(:organization) }

      it "does not send the webhook" do
        described_class.new(organization: other_organization).call
        expect(SendWebhookJob).not_to have_received(:perform_later)
      end
    end

    it "checks last hour events returns the list of transaction_id" do
      result = validation_service.call

      expect(result.errors[:invalid_code]).to include(invalid_code_event.transaction_id)
      expect(result.errors[:missing_aggregation_property])
        .to include(missing_aggregation_property_event.transaction_id)
      expect(result.errors[:missing_aggregation_property])
        .not_to include(negative_aggregation_property_event.transaction_id)
      expect(result.errors[:invalid_filter_values]).to include(invalid_filter_values_event.transaction_id)
    end

    it "delivers a webhook with the list of transaction_id" do
      validation_service.call

      expect(SendWebhookJob).to have_been_enqueued
        .with(
          "events.errors",
          organization,
          errors: {
            invalid_code: [invalid_code_event.transaction_id],
            missing_aggregation_property: [missing_aggregation_property_event.transaction_id],
            invalid_filter_values: [invalid_filter_values_event.transaction_id]
          }
        )
    end
  end
end
