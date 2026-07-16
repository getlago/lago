# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charge do
  subject(:charge) { create(:standard_charge) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to validate_presence_of(:code) }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to have_many(:filters).dependent(:destroy)
      expect(subject).to have_one(:applied_pricing_unit)
      expect(subject).to have_one(:pricing_unit).through(:applied_pricing_unit)
    end
  end

  describe "#validate_graduated" do
    subject(:charge) do
      build(:graduated_charge, properties: charge_properties)
    end

    let(:charge_properties) do
      {graduated_ranges: [{"foo" => "bar"}]}
    end
    let(:validation_service) { instance_double(Charges::Validators::GraduatedService) }

    let(:service_response) do
      BaseService::Result.new.validation_failure!(
        errors: {
          amount: ["invalid_amount"],
          ranges: ["invalid_graduated_ranges"]
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
      expect(charge.errors.messages[:properties]).to include("invalid_graduated_ranges")

      expect(Charges::Validators::GraduatedService).to have_received(:new).with(charge:)
      expect(validation_service).to have_received(:valid?)
      expect(validation_service).to have_received(:result)
    end

    context "when charge model is not graduated" do
      subject(:charge) { build(:standard_charge) }

      it "does not apply the validation" do
        allow(Charges::Validators::GraduatedService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        charge.valid?

        expect(Charges::Validators::GraduatedService).not_to have_received(:new)
        expect(validation_service).not_to have_received(:valid?)
        expect(validation_service).not_to have_received(:result)
      end
    end
  end

  describe "#validate_amount" do
    subject(:charge) do
      build(:standard_charge, properties: charge_properties)
    end

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

    context "when charge model is not graduated" do
      subject(:charge) { build(:graduated_charge) }

      it "does not apply the validation" do
        allow(Charges::Validators::StandardService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        charge.valid?

        expect(Charges::Validators::StandardService).not_to have_received(:new)
        expect(validation_service).not_to have_received(:valid?)
        expect(validation_service).not_to have_received(:result)
      end
    end
  end

  describe "#validate_package" do
    subject(:charge) do
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
      subject(:charge) { build(:standard_charge) }

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

  describe "#validate_percentage" do
    subject(:charge) { build(:percentage_charge, properties: charge_properties) }

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
      subject(:charge) { build(:standard_charge) }

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

  describe "#validate_volume" do
    subject(:charge) do
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
      subject(:charge) { build(:standard_charge) }

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

  describe "#validate_dynamic" do
    subject(:charge) { build(:dynamic_charge, billable_metric:) }

    context "with sum aggregation" do
      let(:billable_metric) { create(:sum_billable_metric) }

      it "is valid" do
        expect(charge).to be_valid
      end
    end

    context "with other aggregation" do
      let(:billable_metric) { create(:latest_billable_metric) }

      it "is invalid" do
        expect(charge).not_to be_valid
        expect(charge.errors[:charge_model]).to include("invalid_aggregation_type_or_charge_model")
      end
    end
  end

  describe "#validate_graduated_percentage" do
    subject(:charge) do
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

  describe "#validate_pay_in_advance" do
    it "does not return an error" do
      expect(build(:standard_charge)).to be_valid
    end

    context "when billable metric is max_agg" do
      it "returns an error" do
        billable_metric = create(:max_billable_metric)
        charge = build(:standard_charge, :pay_in_advance, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:pay_in_advance]).to include("invalid_aggregation_type_or_charge_model")
      end
    end

    context "when billable metric is latest_agg" do
      it "returns an error" do
        billable_metric = create(:latest_billable_metric)
        charge = build(:standard_charge, :pay_in_advance, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:pay_in_advance]).to include("invalid_aggregation_type_or_charge_model")
      end
    end

    context "when billable metric is weighted_sum_agg" do
      it "returns an error" do
        billable_metric = create(:weighted_sum_billable_metric)
        charge = build(:standard_charge, :pay_in_advance, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:pay_in_advance]).to include("invalid_aggregation_type_or_charge_model")
      end
    end

    context "when charge model is volume" do
      it "returns an error" do
        charge = build(:volume_charge, :pay_in_advance)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:pay_in_advance]).to include("invalid_aggregation_type_or_charge_model")
      end
    end
  end

  describe "#validate_regroup_paid_fees" do
    context "when regroup_paid_fees is nil" do
      it "does not return an error when" do
        expect(build(:standard_charge, pay_in_advance: true, invoiceable: true, regroup_paid_fees: nil)).to be_valid
        expect(build(:standard_charge, pay_in_advance: true, invoiceable: false, regroup_paid_fees: nil)).to be_valid
        expect(build(:standard_charge, pay_in_advance: false, invoiceable: true, regroup_paid_fees: nil)).to be_valid
      end
    end

    context "when regroup_paid_fees is `invoice`" do
      it "requires charge to be pay_in_advance and non invoiceable" do
        expect(build(:standard_charge, pay_in_advance: true, invoiceable: false, regroup_paid_fees: "invoice")).to be_valid

        [
          {pay_in_advance: true, invoiceable: true},
          {pay_in_advance: false, invoiceable: true},
          {pay_in_advance: false, invoiceable: false}
        ].each do |params|
          charge = build(:standard_charge, regroup_paid_fees: "invoice", **params)

          expect(charge).not_to be_valid
          expect(charge.errors.messages[:regroup_paid_fees]).to include("only_compatible_with_pay_in_advance_and_non_invoiceable")
        end
      end
    end
  end

  describe "#validate_min_amount_cents" do
    it "does not return an error" do
      expect(build(:standard_charge)).to be_valid
    end

    context "when charge is pay_in_advance" do
      it "returns an error" do
        charge = build(:standard_charge, :pay_in_advance, min_amount_cents: 1200)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:min_amount_cents]).to include("not_compatible_with_pay_in_advance")
      end
    end
  end

  describe "#validate_prorated" do
    let(:billable_metric) { create(:sum_billable_metric, recurring: true) }

    it "does not return error if prorated is false and price model is percentage" do
      expect(build(:percentage_charge, prorated: false)).to be_valid
    end

    context "when charge is standard, pay_in_advance, prorated but BM is not recurring" do
      let(:billable_metric) { create(:billable_metric, recurring: false) }

      it "returns an error" do
        charge = build(:standard_charge, :pay_in_advance, prorated: true, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:prorated]).to include("invalid_billable_metric_or_charge_model")
      end
    end

    context "when charge is package, pay_in_advance, prorated and BM is recurring" do
      it "returns an error" do
        charge = build(:package_charge, :pay_in_advance, prorated: true, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:prorated]).to include("invalid_billable_metric_or_charge_model")
      end
    end

    context "when charge is percentage, pay_in_arrear, prorated and BM is recurring" do
      it "returns an error" do
        charge = build(:percentage_charge, prorated: true, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:prorated]).to include("invalid_billable_metric_or_charge_model")
      end
    end

    context "when billable metric is weighted sum" do
      let(:billable_metric) { create(:weighted_sum_billable_metric) }

      it "returns an error" do
        charge = build(:percentage_charge, prorated: true, billable_metric:)

        expect(charge).not_to be_valid
        expect(charge.errors.messages[:prorated]).to include("invalid_billable_metric_or_charge_model")
      end
    end
  end

  describe "#validate_custom_model" do
    subject(:charge) { build(:charge, billable_metric:, charge_model: "custom") }

    let(:billable_metric) { create(:billable_metric, aggregation_type: :count_agg) }

    it "returns an error for invalid metric type" do
      expect(charge).not_to be_valid
      expect(charge.errors.messages[:charge_model]).to include("invalid_aggregation_type_or_charge_model")
    end
  end

  describe "#pricing_group_keys" do
    subject(:charge) { build(:standard_charge, properties:) }

    let(:properties) { {"amount_cents" => "1000", :pricing_group_keys => ["user_id"]} }

    it "returns the pricing group keys" do
      expect(charge.pricing_group_keys).to eq(["user_id"])
    end

    context "with grouped_by property" do
      let(:properties) { {"amount_cents" => "1000", :grouped_by => ["user_id"]} }

      it "returns the pricing group keys" do
        expect(charge.pricing_group_keys).to eq(["user_id"])
      end
    end
  end

  describe "#presentation_group_keys" do
    subject(:charge) { build(:standard_charge, properties:) }

    context "when presentation_group_keys is present" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => [{"value" => "region"}]} }

      it "returns the presentation group keys" do
        expect(charge.presentation_group_keys).to eq([{"value" => "region"}])
      end
    end

    context "when presentation_group_keys is blank" do
      let(:properties) { {"amount_cents" => "1000"} }

      it "returns nil" do
        expect(charge.presentation_group_keys).to be_nil
      end
    end

    context "when presentation_group_keys is an empty array" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => []} }

      it "returns nil" do
        expect(charge.presentation_group_keys).to be_nil
      end
    end
  end

  describe "#presentation_group_keys_values" do
    subject(:charge) { build(:standard_charge, properties:) }

    context "when presentation_group_keys is blank" do
      let(:properties) { {"amount_cents" => "1000"} }

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values).to eq([])
      end
    end

    context "when presentation_group_keys is nil" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => nil} }

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values).to eq([])
      end
    end

    context "when presentation_group_keys is an empty array" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => []} }

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values).to eq([])
      end
    end

    context "when presentation_group_keys has one element with value" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => [{"value" => "region"}]} }

      it "returns array with the value" do
        expect(charge.presentation_group_keys_values).to eq(["region"])
      end
    end

    context "when presentation_group_keys has multiple elements with values" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region"},
            {"value" => "country"}
          ]
        }
      end

      it "returns array with all values" do
        expect(charge.presentation_group_keys_values).to eq(["region", "country"])
      end
    end

    context "when presentation_group_keys has elements with nil values" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region"},
            {"value" => nil}
          ]
        }
      end

      it "returns array with only non-nil values" do
        expect(charge.presentation_group_keys_values).to eq(["region"])
      end
    end
  end

  describe "#presentation_group_keys_values_displayed_in_invoice" do
    subject(:charge) { build(:standard_charge, properties:) }

    context "when presentation_group_keys is blank" do
      let(:properties) { {"amount_cents" => "1000"} }

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq([])
      end
    end

    context "when presentation_group_keys is an empty array" do
      let(:properties) { {"amount_cents" => "1000", "presentation_group_keys" => []} }

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq([])
      end
    end

    context "when an element has options with display_in_invoice true" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "returns the matching values" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq(["region"])
      end
    end

    context "when an element has options with display_in_invoice false" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => false}}
          ]
        }
      end

      it "returns an empty array" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq([])
      end
    end

    context "when only some elements have display_in_invoice true" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => true}},
            {"value" => "country", "options" => {"display_in_invoice" => false}}
          ]
        }
      end

      it "returns only the values for entries with display_in_invoice true" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq(["region"])
      end
    end

    context "when multiple elements have display_in_invoice true" do
      let(:properties) do
        {
          "amount_cents" => "1000",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => true}},
            {"value" => "department_id", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "returns all matching values" do
        expect(charge.presentation_group_keys_values_displayed_in_invoice).to eq(["region", "department_id"])
      end
    end
  end

  describe "#equal_properties?" do
    let(:charge1) { build(:standard_charge, properties: {amount: 100}) }

    context "when charge model is not the same" do
      let(:charge2) { build(:percentage_charge) }

      it "returns false" do
        expect(charge1.equal_properties?(charge2)).to eq(false)
      end
    end

    context "when charge model is the same and properties are different" do
      let(:charge2) { build(:standard_charge, properties: {amount: 200}) }

      it "returns false if properties are not the same" do
        expect(charge1.equal_properties?(charge2)).to eq(false)
      end
    end

    context "when charge model and properties are the same" do
      let(:charge2) { build(:standard_charge, properties: {amount: 100}) }

      it "returns true if both charge model and properties are the same" do
        expect(charge1.equal_properties?(charge2)).to eq(true)
      end
    end
  end

  describe "#included_in_next_subscription?" do
    subject { charge.included_in_next_subscription?(subscription) }

    let(:charge) { create(:standard_charge) }
    let(:subscription) { create(:subscription, next_subscriptions:) }

    context "when subscription has next subscription" do
      let(:next_subscriptions) { [create(:subscription, plan: next_plan)] }
      let(:next_plan) { build(:plan, charges:) }

      context "when next subscription's plan has charges" do
        let(:charges) { [create(:standard_charge, billable_metric:)] }

        context "when next plan charges includes charge billable metric" do
          let(:billable_metric) { charge.billable_metric }

          it "returns true" do
            expect(subject).to be true
          end
        end

        context "when next plan charges does not include charge billable metric" do
          let(:billable_metric) { create(:billable_metric) }

          it "returns false" do
            expect(subject).to be false
          end
        end
      end

      context "when next subscription's plan has no charges" do
        let(:charges) { [] }

        it "returns false" do
          expect(subject).to be false
        end
      end
    end

    context "when subscription has no next subscription" do
      let(:next_subscriptions) { [] }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe "validations" do
    subject { charge.valid? }

    describe "code" do
      it "validates uniqueness scoped to plan_id for parent charges" do
        existing_charge = create(:standard_charge, code: "my_code")
        new_charge = build(:standard_charge, code: "my_code", plan: existing_charge.plan)
        expect(new_charge).not_to be_valid
        expect(new_charge.errors[:code]).to include("value_already_exist")
      end

      it "allows same code on different plans" do
        create(:standard_charge, code: "my_code")
        new_charge = build(:standard_charge, code: "my_code")
        expect(new_charge).to be_valid
      end

      it "allows same code on soft-deleted charges" do
        existing_charge = create(:standard_charge, code: "my_code")
        existing_charge.discard
        new_charge = build(:standard_charge, code: "my_code", plan: existing_charge.plan)
        expect(new_charge).to be_valid
      end

      it "allows same code for child charges" do
        parent_charge = create(:standard_charge, code: "my_code")
        child_charge = build(:standard_charge, code: "my_code", plan: parent_charge.plan, parent: parent_charge)
        expect(child_charge).to be_valid
      end
    end

    describe "#validate_invoiceable_unless_pay_in_advance" do
      let(:charge) { build_stubbed(:standard_charge, pay_in_advance:, invoiceable:) }

      context "when pay_in_advance is true" do
        let(:pay_in_advance) { true }

        context "with invoiceable set to true" do
          let(:invoiceable) { true }

          it "is valid" do
            expect(subject).to be true
          end
        end

        context "with invoiceable set to false" do
          let(:invoiceable) { false }

          it "is valid" do
            expect(subject).to be true
          end
        end
      end

      context "when pay_in_advance is false" do
        let(:pay_in_advance) { false }

        context "with invoiceable set to true" do
          let(:invoiceable) { true }

          it "is valid" do
            expect(subject).to be true
          end
        end

        context "with invoiceable set to false" do
          let(:invoiceable) { false }

          it "is invalid" do
            expect(subject).to be false
            expect(charge.errors[:invoiceable]).to include("must_be_true_unless_pay_in_advance")
          end
        end
      end
    end

    describe "of charge model" do
      let(:error) { charge.errors.where(:charge_model, :graduated_percentage_requires_premium_license) }
      let(:charge) { build_stubbed(:charge, charge_model:, properties:) }
      let(:properties) { attributes_for("#{charge_model}_charge")[:properties] }

      context "when premium", :premium do
        before { subject }

        context "when charge model is graduated percentage" do
          let(:charge_model) { :graduated_percentage }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end

        context "when charge model is non graduated percentage" do
          let(:charge_model) { described_class::CHARGE_MODELS.excluding(:graduated_percentage).sample }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end

      context "when freemium" do
        before { subject }

        context "when charge model is graduated percentage" do
          let(:charge_model) { :graduated_percentage }

          it "adds an error" do
            expect(error).to be_present
          end
        end

        context "when charge model is non graduated percentage" do
          let(:charge_model) { described_class::CHARGE_MODELS.excluding(:graduated_percentage).sample }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end
    end
  end

  describe "#validate_accepts_target_wallet" do
    let(:organization) { create(:organization) }
    let(:plan) { create(:plan, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }

    context "when accepts_target_wallet is false" do
      it "is valid" do
        charge = build(:standard_charge, plan:, billable_metric:, accepts_target_wallet: false)
        expect(charge).to be_valid
      end
    end

    context "when accepts_target_wallet is true" do
      context "when feature is not enabled" do
        it "returns an error" do
          charge = build(:standard_charge, plan:, billable_metric:, accepts_target_wallet: true)

          expect(charge).not_to be_valid
          expect(charge.errors[:accepts_target_wallet]).to include("feature_unavailable")
        end
      end

      context "when premium license is active but integration is not enabled", :premium do
        it "returns an error" do
          charge = build(:standard_charge, plan:, billable_metric:, accepts_target_wallet: true)

          expect(charge).not_to be_valid
          expect(charge.errors[:accepts_target_wallet]).to include("feature_unavailable")
        end
      end

      context "when feature is enabled", :premium do
        before do
          organization.update!(premium_integrations: ["events_targeting_wallets"])
        end

        it "is valid" do
          charge = build(:standard_charge, plan:, billable_metric:, accepts_target_wallet: true)
          expect(charge).to be_valid
        end
      end
    end
  end

  describe "#equal_applied_pricing_unit_rate?" do
    subject { charge.equal_applied_pricing_unit_rate?(another_charge) }

    let(:charge) { build(:standard_charge, applied_pricing_unit:) }

    let(:another_charge) do
      build(
        :standard_charge,
        applied_pricing_unit: build(:applied_pricing_unit)
      )
    end

    context "when has associated applied pricing unit" do
      let(:applied_pricing_unit) { build(:applied_pricing_unit, conversion_rate:) }

      context "when charges conversion rate is equal" do
        let(:conversion_rate) { another_charge.applied_pricing_unit.conversion_rate }

        it "returns true" do
          expect(subject).to be true
        end
      end

      context "when charges conversion rate is not equal" do
        let(:conversion_rate) { another_charge.applied_pricing_unit.conversion_rate - 0.5 }

        it "returns false" do
          expect(subject).to be false
        end
      end
    end

    context "when has no associated applied pricing unit" do
      let(:applied_pricing_unit) { nil }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end
end
