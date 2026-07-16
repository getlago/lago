# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::MatchingAndIgnoredService do
  subject(:service_result) { described_class.call(charge:, filter: current_filter) }

  let(:billable_metric) { create(:billable_metric) }
  let(:charge) { create(:standard_charge, billable_metric:) }

  let(:filter_steps) { create(:billable_metric_filter, billable_metric:, key: "steps", values: %w[25 50 75 100]) }
  let(:filter_size) { create(:billable_metric_filter, billable_metric:, key: "size", values: %w[512 1024]) }
  let(:filter_model) do
    create(:billable_metric_filter, billable_metric:, key: "model", values: %w[llama-1 llama-2 llama-3 llama-4])
  end

  let(:f1) { create(:charge_filter, charge:, invoice_display_name: "f1") }
  let(:f1_values) do
    [
      create(:charge_filter_value, values: ["25"], billable_metric_filter: filter_steps, charge_filter: f1),
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: f1),
      create(:charge_filter_value, values: ["llama-2"], billable_metric_filter: filter_model, charge_filter: f1)
    ]
  end

  let(:f2) { create(:charge_filter, charge:, invoice_display_name: "f2") }
  let(:f2_values) do
    [
      create(:charge_filter_value, values: ["25"], billable_metric_filter: filter_steps, charge_filter: f2),
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: f2)
    ]
  end

  let(:f3) { create(:charge_filter, charge:, invoice_display_name: "f3") }
  let(:f3_values) do
    [
      create(
        :charge_filter_value,
        values: [ChargeFilterValue::ALL_FILTER_VALUES],
        billable_metric_filter: filter_steps,
        charge_filter: f3
      ),
      create(
        :charge_filter_value,
        values: [ChargeFilterValue::ALL_FILTER_VALUES],
        billable_metric_filter: filter_size,
        charge_filter: f3
      )
    ]
  end

  let(:f4) { create(:charge_filter, charge:, invoice_display_name: "f4") }
  let(:f4_values) do
    [
      create(
        :charge_filter_value,
        values: [ChargeFilterValue::ALL_FILTER_VALUES],
        billable_metric_filter: filter_size,
        charge_filter: f4
      )
    ]
  end

  let(:f5) { create(:charge_filter, charge:, invoice_display_name: "f5") }
  let(:f5_values) do
    [
      create(
        :charge_filter_value,
        values: ["512"],
        billable_metric_filter: filter_size,
        charge_filter: f5
      )
    ]
  end

  before do
    f1
    f1_values
    f2
    f2_values
    f3
    f3_values
    f4
    f4_values
    f5
    f5_values
  end

  describe "for f1" do
    let(:current_filter) { f1 }

    it "returns a formatted hash" do
      expect(service_result.matching_filters).to eq({"size" => %w[512], "steps" => %w[25], "model" => %w[llama-2]})
      expect(service_result.ignored_filters).to eq([])
    end
  end

  describe "for f2" do
    let(:current_filter) { f2 }

    it "returns a formatted hash" do
      expect(service_result.matching_filters).to eq({"size" => %w[512], "steps" => %w[25]})
      expect(service_result.ignored_filters).to eq(
        [
          {"model" => %w[llama-2], "size" => %w[512], "steps" => %w[25]},
          {"size" => ["1024"], "steps" => %w[50 75 100]}
        ]
      )
    end
  end

  describe "for f3" do
    let(:current_filter) { f3 }

    it "returns a formatted hash" do
      expect(service_result.matching_filters).to eq({"size" => %w[512 1024], "steps" => %w[25 50 75 100]})
      expect(service_result.ignored_filters).to eq(
        [
          {"model" => ["llama-2"], "size" => ["512"], "steps" => ["25"]},
          {"size" => ["512"], "steps" => ["25"]}
        ]
      )
    end
  end

  describe "for f4" do
    let(:current_filter) { f4 }

    it "returns a formatted hash" do
      expect(service_result.matching_filters).to eq({"size" => %w[512 1024]})
      expect(service_result.ignored_filters).to eq(
        [
          {"model" => ["llama-2"], "size" => ["512"], "steps" => ["25"]},
          {"size" => ["512"], "steps" => ["25"]},
          {"size" => %w[512 1024], "steps" => %w[25 50 75 100]},
          {"size" => ["512"]}
        ]
      )
    end
  end

  describe "for f5" do
    let(:current_filter) { f5 }

    it "returns a formatted hash" do
      expect(service_result.matching_filters).to eq({"size" => %w[512]})
      expect(service_result.ignored_filters).to eq(
        [
          {"model" => ["llama-2"], "size" => ["512"], "steps" => ["25"]},
          {"size" => ["512"], "steps" => ["25"]},
          {"size" => %w[512 1024], "steps" => %w[25 50 75 100]},
          {"size" => ["1024"]}
        ]
      )
    end
  end

  # The following contexts cover edge cases where ignored_filters contains
  # empty hashes or hashes with all-empty-array values. These states should
  # not occur in normal usage — charge filters should always have values,
  # and duplicate filters should not exist — but missing validations allow
  # them in production. The store-level defensive guards (ISSUE-1799) prevent
  # these from producing invalid SQL.

  context "when a filter has no values" do
    subject(:service_result) { described_class.call(charge: isolated_charge, filter: current_filter) }

    let(:isolated_charge) { create(:standard_charge, billable_metric:) }

    let(:empty_a) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "empty_a") }
    let(:empty_b) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "empty_b") }
    let(:with_values) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "with_values") }

    before do
      empty_a
      empty_b
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: with_values)
    end

    describe "for empty_a" do
      let(:current_filter) { empty_a }

      it "produces empty hashes in ignored_filters from other empty filters" do
        expect(service_result.matching_filters).to eq({})
        expect(service_result.ignored_filters).to eq(
          [
            {},
            {"size" => ["512"]}
          ]
        )
      end
    end

    describe "for with_values" do
      let(:current_filter) { with_values }

      it "does not include empty filters as children" do
        expect(service_result.matching_filters).to eq({"size" => ["512"]})
        expect(service_result.ignored_filters).to eq([])
      end
    end
  end

  context "when a child's values are a subset of the parent's" do
    subject(:service_result) { described_class.call(charge: isolated_charge, filter: current_filter) }

    let(:isolated_charge) { create(:standard_charge, billable_metric:) }

    let(:parent_filter) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "parent") }
    let(:subset_child) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "subset_child") }
    let(:partial_overlap) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "partial") }

    before do
      create(:charge_filter_value, values: %w[512 1024], billable_metric_filter: filter_size, charge_filter: parent_filter)
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: subset_child)
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: partial_overlap)
      create(:charge_filter_value, values: ["25"], billable_metric_filter: filter_steps, charge_filter: partial_overlap)
    end

    describe "for parent_filter" do
      let(:current_filter) { parent_filter }

      it "produces all-empty-values entry from subset child and keeps different-key children intact" do
        expect(service_result.matching_filters).to eq({"size" => %w[512 1024]})
        expect(service_result.ignored_filters).to eq(
          [
            {"size" => []},
            {"size" => ["512"], "steps" => ["25"]}
          ]
        )
      end
    end
  end

  context "when two filters have identical keys and values" do
    subject(:service_result) { described_class.call(charge: isolated_charge, filter: current_filter) }

    let(:isolated_charge) { create(:standard_charge, billable_metric:) }

    let(:filter_a) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "filter_a") }
    let(:filter_b) { create(:charge_filter, charge: isolated_charge, invoice_display_name: "filter_b") }

    before do
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: filter_a)
      create(:charge_filter_value, values: ["25"], billable_metric_filter: filter_steps, charge_filter: filter_a)
      create(:charge_filter_value, values: ["512"], billable_metric_filter: filter_size, charge_filter: filter_b)
      create(:charge_filter_value, values: ["25"], billable_metric_filter: filter_steps, charge_filter: filter_b)
    end

    describe "for filter_a" do
      let(:current_filter) { filter_a }

      it "produces all-empty-values entry from the identical sibling" do
        expect(service_result.matching_filters).to eq({"size" => ["512"], "steps" => ["25"]})
        expect(service_result.ignored_filters).to eq(
          [{"size" => [], "steps" => []}]
        )
      end
    end
  end
end
