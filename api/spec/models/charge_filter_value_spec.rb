# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilterValue do
  subject { build(:charge_filter_value) }

  it_behaves_like "paper_trail traceable"

  describe "associations" do
    it do
      expect(subject).to belong_to(:charge_filter)
      expect(subject).to belong_to(:billable_metric_filter)
      expect(subject).to belong_to(:organization)
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:values)
    end
  end

  describe "#valdiate_values" do
    subject(:charge_filter_value) do
      build(:charge_filter_value, billable_metric_filter:, values:)
    end

    let(:billable_metric_filter) { create(:billable_metric_filter) }
    let(:values) { [billable_metric_filter.values.first] }

    it { expect(charge_filter_value).to be_valid }

    context "when value is not included in billable_metric_filter values" do
      let(:values) { ["invalid_value"] }

      it do
        expect(charge_filter_value).to be_invalid
        expect(charge_filter_value.errors[:values]).to include("value_is_invalid")
      end
    end

    context "when values are empty" do
      let(:values) { [] }

      it do
        expect(charge_filter_value).to be_invalid
        expect(charge_filter_value.errors[:values]).to include("value_is_mandatory")
      end
    end

    context "when value is ALL_FILTER_VALUES" do
      let(:values) { [ChargeFilterValue::ALL_FILTER_VALUES] }

      it { expect(charge_filter_value).to be_valid }
    end
  end
end
