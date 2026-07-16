# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::EventMatchingService do
  subject(:service_result) { described_class.call(charge:, event:) }

  let(:organization) { create(:organization) }

  let(:event_properties) do
    {
      payment_method: "card",
      card_location: "domestic",
      scheme: "visa",
      card_type: "credit",
      card_number: 2
    }
  end

  let(:event) do
    create(
      :event,
      organization_id: organization.id,
      code: billable_metric.code,
      properties: event_properties
    )
  end

  let(:billable_metric) { create(:billable_metric, organization:) }

  let(:charge) { create(:standard_charge, billable_metric:) }

  let(:payment_method) do
    create(:billable_metric_filter, billable_metric:, key: "payment_method", values: %i[card virtual_card transfer])
  end
  let(:card_location) { create(:billable_metric_filter, billable_metric:, key: "card_location", values: %i[domestic]) }
  let(:scheme) { create(:billable_metric_filter, billable_metric:, key: "scheme", values: %i[visa mastercard]) }
  let(:card_type) { create(:billable_metric_filter, billable_metric:, key: "card_type", values: %i[credit debit]) }
  let(:card_number) { create(:billable_metric_filter, billable_metric:, key: "card_number", values: %i[1 2 3]) }

  let(:filter1) { create(:charge_filter, charge:) }
  let(:filter1_values) do
    [
      create(:charge_filter_value, values: ["card"], billable_metric_filter: payment_method, charge_filter: filter1),
      create(:charge_filter_value, values: ["domestic"], billable_metric_filter: card_location, charge_filter: filter1),
      create(
        :charge_filter_value,
        values: %w[visa mastercard],
        billable_metric_filter: scheme,
        charge_filter: filter1
      )
    ]
  end

  let(:filter2) { create(:charge_filter, charge:) }
  let(:filter2_values) do
    [
      create(:charge_filter_value, values: ["card"], billable_metric_filter: payment_method, charge_filter: filter2),
      create(:charge_filter_value, values: ["domestic"], billable_metric_filter: card_location, charge_filter: filter2),
      create(
        :charge_filter_value,
        values: %w[visa mastercard],
        billable_metric_filter: scheme,
        charge_filter: filter2
      ),
      create(:charge_filter_value, values: ["credit"], billable_metric_filter: card_type, charge_filter: filter2),
      create(:charge_filter_value, values: ["2"], billable_metric_filter: card_number, charge_filter: filter2)
    ]
  end

  before do
    filter1_values
    filter2_values
  end

  it "returns the filter matching the most properties" do
    expect(service_result.charge_filter).to eq(filter2)
  end

  context "when event does not match any filter" do
    let(:event_properties) { {} }

    it "returns nil" do
      expect(service_result.charge_filter).to be_nil
    end
  end

  context "with an ALL_FILTER_VALUES filter" do
    let(:filter2_values) do
      [
        create(:charge_filter_value, values: ["card"], billable_metric_filter: payment_method, charge_filter: filter2),
        create(:charge_filter_value, values: ["domestic"], billable_metric_filter: card_location, charge_filter: filter2),
        create(
          :charge_filter_value,
          values: [ChargeFilterValue::ALL_FILTER_VALUES],
          billable_metric_filter: scheme,
          charge_filter: filter2
        ),
        create(:charge_filter_value, values: ["credit"], billable_metric_filter: card_type, charge_filter: filter2),
        create(:charge_filter_value, values: ["2"], billable_metric_filter: card_number, charge_filter: filter2)
      ]
    end

    it "returns the filter matching the most properties" do
      expect(service_result.charge_filter).to eq(filter2)
    end
  end
end
