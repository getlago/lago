# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilter do
  subject(:charge_filter) { build(:charge_filter) }

  it_behaves_like "paper_trail traceable"

  describe "associations" do
    it do
      expect(subject).to belong_to(:charge)
      expect(subject).to belong_to(:organization)
      expect(subject).to have_many(:values).dependent(:destroy)
      expect(subject).to have_many(:fees)
    end
  end

  describe "#validate_properties" do
    subject(:charge_filter) { build(:charge_filter, charge:, properties: charge_properties) }

    let(:charge) do
      build(:standard_charge)
    end

    context "when charge model is standard" do
      let(:charge_properties) { [{"foo" => "bar"}] }
      let(:validation_service) { instance_double(Charges::Validators::StandardService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            amount: ["invalid_amount"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::StandardService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_amount")

        expect(Charges::Validators::StandardService).to have_received(:new).with(charge:)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end
    end

    context "when charge model is graduated" do
      let(:charge) { build(:graduated_charge) }
      let(:charge_properties) { {graduated_ranges: [{"foo" => "bar"}]} }

      let(:validation_service) { instance_double(Charges::Validators::GraduatedService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            per_unit_amount: ["invalid_amount"],
            flat_amount: ["invalid_amount"],
            graduated_ranges: ["missing_graduated_ranges"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::GraduatedService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_amount")
        expect(charge.errors.messages[:properties]).to include("missing_graduated_ranges")

        expect(Charges::Validators::GraduatedService).to have_received(:new)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end
    end

    context "when charge model is package" do
      let(:charge) do
        build(:package_charge, properties: charge_properties)
      end

      let(:charge_properties) { [{"foo" => "bar"}] }
      let(:validation_service) { instance_double(Charges::Validators::PackageService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            amount: ["invalid_amount"],
            free_units: ["invalid_free_units"],
            package_size: ["invalid_package_size"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::PackageService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_amount")
        expect(charge.errors.messages[:properties]).to include("invalid_free_units")
        expect(charge.errors.messages[:properties]).to include("invalid_package_size")

        expect(Charges::Validators::PackageService).to have_received(:new).with(charge:)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end

      context "when charge model is not package" do
        let(:charge) { build(:standard_charge) }

        it "does not apply the validation" do
          allow(Charges::Validators::PackageService).to receive(:new)
            .and_return(validation_service)
          allow(validation_service).to receive(:valid?)
            .and_return(false)
          allow(validation_service).to receive(:result)
            .and_return(service_response)

          charge.valid?

          expect(Charges::Validators::PackageService).not_to have_received(:new)
          expect(validation_service).not_to have_received(:valid?)
          expect(validation_service).not_to have_received(:result)
        end
      end
    end

    context "when charge model is percentage" do
      let(:charge) { build(:percentage_charge, properties: charge_properties) }

      let(:charge_properties) { [{"foo" => "bar"}] }
      let(:validation_service) { instance_double(Charges::Validators::PercentageService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            amount: ["invalid_fixed_amount"],
            free_units_per_events: ["invalid_free_units_per_events"],
            free_units_per_total_aggregation: ["invalid_free_units_per_total_aggregation"],
            rate: ["invalid_rate"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::PercentageService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_rate")
        expect(charge.errors.messages[:properties]).to include("invalid_fixed_amount")
        expect(charge.errors.messages[:properties]).to include("invalid_free_units_per_events")
        expect(charge.errors.messages[:properties]).to include("invalid_free_units_per_total_aggregation")

        expect(Charges::Validators::PercentageService).to have_received(:new).with(charge:)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end

      context "when charge model is not percentage" do
        let(:charge) { build(:standard_charge) }

        it "does not apply the validation" do
          allow(Charges::Validators::PercentageService).to receive(:new)
            .and_return(validation_service)
          allow(validation_service).to receive(:valid?)
            .and_return(false)
          allow(validation_service).to receive(:result)
            .and_return(service_response)
          charge.valid?

          expect(Charges::Validators::PercentageService).not_to have_received(:new)
          expect(validation_service).not_to have_received(:valid?)
          expect(validation_service).not_to have_received(:result)
        end
      end
    end

    context "when charge model is volume" do
      let(:charge) do
        build(:volume_charge, properties: charge_properties)
      end

      let(:charge_properties) { {volume_ranges: [{"foo" => "bar"}]} }
      let(:validation_service) { instance_double(Charges::Validators::VolumeService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            amount: ["invalid_amount"],
            volume_ranges: ["invalid_volume_ranges"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::VolumeService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_amount")
        expect(charge.errors.messages[:properties]).to include("invalid_volume_ranges")

        expect(Charges::Validators::VolumeService).to have_received(:new).with(charge:)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end

      context "when charge model is not volume" do
        let(:charge) { build(:standard_charge) }

        it "does not apply the validation" do
          allow(Charges::Validators::VolumeService).to receive(:new)
            .and_return(validation_service)
          allow(validation_service).to receive(:valid?)
            .and_return(false)
          allow(validation_service).to receive(:result)
            .and_return(service_response)

          charge.valid?

          expect(Charges::Validators::VolumeService).not_to have_received(:new)
          expect(validation_service).not_to have_received(:valid?)
          expect(validation_service).not_to have_received(:result)
        end
      end
    end

    context "when charge model is graduated percentage" do
      let(:charge) do
        build(:graduated_percentage_charge, properties: charge_properties)
      end

      let(:charge_properties) do
        {graduated_percentage_ranges: [{"foo" => "bar"}]}
      end
      let(:validation_service) { instance_double(Charges::Validators::GraduatedPercentageService) }

      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {
            rate: ["invalid_rate"],
            ranges: ["invalid_graduated_percentage_ranges"]
          }
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::GraduatedPercentageService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(charge).not_to be_valid
        expect(charge.errors.messages.keys).to include(:properties)
        expect(charge.errors.messages[:properties]).to include("invalid_rate")
        expect(charge.errors.messages[:properties]).to include("invalid_graduated_percentage_ranges")

        expect(Charges::Validators::GraduatedPercentageService).to have_received(:new).with(charge:)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end

      context "when charge model is not graduated percentage" do
        subject(:charge) { build(:standard_charge) }

        it "does not apply the validation" do
          allow(Charges::Validators::GraduatedPercentageService).to receive(:new)
            .and_return(validation_service)
          allow(validation_service).to receive(:valid?)
            .and_return(false)
          allow(validation_service).to receive(:result)
            .and_return(service_response)

          charge.valid?

          expect(Charges::Validators::GraduatedPercentageService).not_to have_received(:new)
          expect(validation_service).not_to have_received(:valid?)
          expect(validation_service).not_to have_received(:result)
        end
      end
    end
  end

  describe "#display_name" do
    subject(:charge_filter) { create(:charge_filter, charge:, invoice_display_name:) }

    let(:charge) { create(:standard_charge) }
    let(:method_filter) { create(:billable_metric_filter, key: "card", values: %w[card apple_pay]) }
    let(:scheme_filter) { create(:billable_metric_filter, key: "card", values: %w[visa mastercard]) }

    let(:invoice_display_name) { Faker::Fantasy::Tolkien.character }
    let(:values) do
      [
        create(:charge_filter_value, values: ["card"], charge_filter:, billable_metric_filter: method_filter),
        create(:charge_filter_value, values: ["visa"], charge_filter:, billable_metric_filter: scheme_filter)
      ]
    end

    before { values }

    it "returns the invoice display name" do
      expect(charge_filter.display_name).to eq(invoice_display_name)
    end

    context "when invoice display name is not present" do
      let(:invoice_display_name) { nil }

      it "returns the values joined" do
        expect(charge_filter.display_name).to eq("card, visa")
      end
    end
  end

  describe "#to_h" do
    subject(:charge_filter) { create(:charge_filter) }

    let(:card) { create(:billable_metric_filter, key: "card", values: %w[credit debit]) }
    let(:scheme) { create(:billable_metric_filter, key: "scheme", values: %w[visa mastercard]) }
    let(:values) do
      [
        create(:charge_filter_value, charge_filter:, values: ["credit"], billable_metric_filter: card),
        create(:charge_filter_value, charge_filter:, values: ["visa"], billable_metric_filter: scheme)
      ]
    end
    let(:card_filter_value) { values.first }

    before { values }

    it "returns the values as a memoized frozen hash" do
      original_values = {"card" => ["credit"], "scheme" => ["visa"]}
      expect(charge_filter.to_h).to eq(original_values)

      expect(charge_filter.to_h).to be_frozen

      card_filter_value.update(values: ["debit"])
      charge_filter.values.reload

      expect(charge_filter.to_h).to eq(original_values)

      expect(described_class.find(charge_filter.id).to_h).to eq({
        "card" => ["debit"],
        "scheme" => ["visa"]
      })
    end
  end

  describe "#to_h_with_discarded" do
    subject(:charge_filter) { create(:charge_filter) }

    let(:card) { create(:billable_metric_filter, key: "card", values: %w[credit debit]) }
    let(:scheme) { create(:billable_metric_filter, key: "scheme", values: %w[visa mastercard]) }
    let(:values) do
      [
        create(:charge_filter_value, charge_filter:, values: ["credit"], billable_metric_filter: card).tap(&:discard),
        create(:charge_filter_value, charge_filter:, values: ["visa"], billable_metric_filter: scheme).tap(&:discard)
      ]
    end
    let(:card_filter_value) { values.first }

    before { values }

    it "returns the values as a hash" do
      original_values = {"card" => ["credit"], "scheme" => ["visa"]}
      expect(charge_filter.to_h_with_discarded).to eq(original_values)
      expect(charge_filter.to_h_with_discarded).to be_frozen

      card_filter_value.update(values: ["debit"])
      charge_filter.values.reload

      expect(charge_filter.to_h_with_discarded).to eq(original_values)

      expect(described_class.find(charge_filter.id).to_h_with_discarded).to eq({
        "card" => ["debit"],
        "scheme" => ["visa"]
      })
    end
  end

  describe "#to_h_with_all_values" do
    subject(:charge_filter) { create(:charge_filter, values:) }

    let(:card) { create(:billable_metric_filter, key: "card", values: %w[credit debit]) }
    let(:scheme) { create(:billable_metric_filter, key: "scheme", values: %w[visa mastercard]) }
    let(:values) do
      [
        build(:charge_filter_value, values: ["credit"], billable_metric_filter: card),
        build(:charge_filter_value, values: [ChargeFilterValue::ALL_FILTER_VALUES], billable_metric_filter: scheme)
      ]
    end
    let(:card_filter_value) { values.first }

    it "returns all values as a memoized frozen hash" do
      original_values = {"card" => ["credit"], "scheme" => %w[visa mastercard]}
      expect(charge_filter.to_h_with_all_values).to eq(original_values)
      expect(charge_filter.to_h_with_all_values).to be_frozen

      card_filter_value.update(values: ["debit"])
      charge_filter.values.reload

      expect(charge_filter.to_h_with_all_values).to eq(original_values)

      expect(described_class.find(charge_filter.id).to_h_with_all_values).to eq({
        "card" => ["debit"],
        "scheme" => %w[visa mastercard]
      })
    end
  end

  describe "#pricing_group_keys" do
    subject(:charge_filter) { build(:charge_filter, properties:) }

    let(:properties) { {"amount_cents" => "1000", :pricing_group_keys => ["user_id"]} }

    it "returns the pricing group keys" do
      expect(charge_filter.pricing_group_keys).to eq(["user_id"])
    end

    context "with grouped_by property" do
      let(:properties) { {"amount_cents" => "1000", :grouped_by => ["user_id"]} }

      it "returns the pricing group keys" do
        expect(charge_filter.pricing_group_keys).to eq(["user_id"])
      end
    end
  end
end
