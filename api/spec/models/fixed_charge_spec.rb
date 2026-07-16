# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharge do
  subject { build(:fixed_charge) }

  it_behaves_like "paper_trail traceable"

  it { expect(described_class).to be_soft_deletable }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:plan) }
  it { is_expected.to belong_to(:add_on) }
  it { is_expected.to belong_to(:parent).class_name("FixedCharge").optional }
  it { is_expected.to have_many(:children).class_name("FixedCharge").dependent(:nullify) }
  it { is_expected.to have_many(:applied_taxes).class_name("FixedCharge::AppliedTax").dependent(:destroy) }
  it { is_expected.to have_many(:taxes).through(:applied_taxes) }
  it { is_expected.to have_many(:fees) }
  it { is_expected.to have_many(:events).class_name("FixedChargeEvent").dependent(:destroy) }
  it { is_expected.to have_many(:subscription_units_overrides).class_name("Subscription::FixedChargeUnitsOverride") }

  it { is_expected.to validate_numericality_of(:units).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_presence_of(:charge_model) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_exclusion_of(:pay_in_advance).in_array([nil]) }
  it { is_expected.to validate_exclusion_of(:prorated).in_array([nil]) }
  it { is_expected.to validate_presence_of(:properties) }

  describe "validations" do
    describe "code" do
      it "validates uniqueness scoped to plan_id for parent fixed_charges" do
        existing = create(:fixed_charge, code: "my_code")
        new_fixed_charge = build(:fixed_charge, code: "my_code", plan: existing.plan)
        expect(new_fixed_charge).not_to be_valid
        expect(new_fixed_charge.errors[:code]).to include("value_already_exist")
      end

      it "allows same code on different plans" do
        create(:fixed_charge, code: "my_code")
        new_fixed_charge = build(:fixed_charge, code: "my_code")
        expect(new_fixed_charge).to be_valid
      end

      it "allows same code on soft-deleted fixed_charges" do
        existing = create(:fixed_charge, code: "my_code")
        existing.discard
        new_fixed_charge = build(:fixed_charge, code: "my_code", plan: existing.plan)
        expect(new_fixed_charge).to be_valid
      end

      it "allows same code for child fixed_charges" do
        parent = create(:fixed_charge, code: "my_code")
        child = build(:fixed_charge, code: "my_code", plan: parent.plan, parent:)
        expect(child).to be_valid
      end
    end
  end

  describe "#validate_properties" do
    context "with standard charge model" do
      subject(:fixed_charge) { build(:fixed_charge, charge_model: "standard", properties:) }

      let(:properties) { {amount: "invalid"} }
      let(:validation_service) { instance_double(Charges::Validators::StandardService) }
      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {amount: ["invalid_amount"]}
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::StandardService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(fixed_charge).not_to be_valid
        expect(fixed_charge.errors.messages.keys).to include(:properties)
        expect(fixed_charge.errors.messages[:properties]).to include("invalid_amount")

        expect(Charges::Validators::StandardService).to have_received(:new).with(charge: fixed_charge)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end
    end

    context "with graduated charge model" do
      subject(:fixed_charge) { build(:fixed_charge, :graduated, properties:) }

      let(:properties) { {graduated_ranges: [{"foo" => "bar"}]} }
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

        expect(fixed_charge).not_to be_valid
        expect(fixed_charge.errors.messages.keys).to include(:properties)
        expect(fixed_charge.errors.messages[:properties]).to include("invalid_amount")
        expect(fixed_charge.errors.messages[:properties]).to include("invalid_graduated_ranges")

        expect(Charges::Validators::GraduatedService).to have_received(:new).with(charge: fixed_charge)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end
    end

    context "with volume charge model" do
      subject(:fixed_charge) { build(:fixed_charge, :volume, properties:) }

      let(:properties) { {volume_ranges: [{"foo" => "bar"}]} }
      let(:validation_service) { instance_double(Charges::Validators::VolumeService) }
      let(:service_response) do
        BaseService::Result.new.validation_failure!(
          errors: {ranges: ["invalid_volume_ranges"]}
        )
      end

      it "delegates to a validation service" do
        allow(Charges::Validators::VolumeService).to receive(:new)
          .and_return(validation_service)
        allow(validation_service).to receive(:valid?)
          .and_return(false)
        allow(validation_service).to receive(:result)
          .and_return(service_response)

        expect(fixed_charge).not_to be_valid
        expect(fixed_charge.errors.messages.keys).to include(:properties)
        expect(fixed_charge.errors.messages[:properties]).to include("invalid_volume_ranges")

        expect(Charges::Validators::VolumeService).to have_received(:new).with(charge: fixed_charge)
        expect(validation_service).to have_received(:valid?)
        expect(validation_service).to have_received(:result)
      end
    end
  end

  describe "scopes" do
    let(:scoped) { create(:fixed_charge) }
    let(:deleted) { create(:fixed_charge, :deleted) }
    let(:pay_in_advance) { create(:fixed_charge, pay_in_advance: true) }
    let(:pay_in_arrears) { create(:fixed_charge, pay_in_advance: false) }

    before do
      scoped
      deleted
      pay_in_advance
      pay_in_arrears
    end

    describe ".all" do
      it "returns all not deleted fixed charges" do
        expect(described_class.all).to match_array([scoped, pay_in_advance, pay_in_arrears])
      end
    end

    describe ".pay_in_advance" do
      it "returns only pay_in_advance fixed charges" do
        expect(described_class.pay_in_advance).to match_array([pay_in_advance])
      end
    end

    describe ".pay_in_arrears" do
      it "returns only pay_in_arrears fixed charges" do
        expect(described_class.pay_in_arrears).to match_array([pay_in_arrears, scoped])
      end
    end
  end

  describe "#equal_properties?" do
    subject(:equal_properties?) { fixed_charge1.equal_properties?(fixed_charge2) }

    let(:fixed_charge1) do
      build(:fixed_charge, :standard, units: 2, properties: {amount: 100})
    end

    context "when charge model is not the same" do
      let(:fixed_charge2) do
        build(
          :fixed_charge,
          charge_model: :volume,
          properties: fixed_charge1.properties,
          units: fixed_charge1.units
        )
      end

      it { is_expected.to be false }
    end

    context "when properties are different" do
      let(:fixed_charge2) do
        build(
          :fixed_charge,
          charge_model: fixed_charge1.charge_model,
          properties: {amount: 200},
          units: fixed_charge1.units
        )
      end

      it { is_expected.to be false }
    end

    context "when units are different" do
      let(:fixed_charge2) do
        build(
          :fixed_charge,
          charge_model: fixed_charge1.charge_model,
          properties: fixed_charge1.properties,
          units: 99999
        )
      end

      it { is_expected.to be false }
    end

    context "when charge model, properties and units are the same" do
      let(:fixed_charge2) do
        build(
          :fixed_charge,
          charge_model: fixed_charge1.charge_model,
          properties: fixed_charge1.properties,
          units: fixed_charge1.units
        )
      end

      it { is_expected.to be true }
    end
  end

  describe "#parent_or_self" do
    context "when the fixed charge has a parent" do
      let(:parent) { create(:fixed_charge) }
      let(:fixed_charge) { create(:fixed_charge, parent:) }

      it "returns the parent fixed charge" do
        expect(fixed_charge.parent_or_self).to eq(parent)
      end
    end

    context "when the fixed charge has no parent" do
      let(:fixed_charge) { create(:fixed_charge) }

      it "returns itself" do
        expect(fixed_charge.parent_or_self).to eq(fixed_charge)
      end
    end
  end

  describe "#validate_pay_in_advance" do
    context "when charge model is standard" do
      it "is valid with pay_in_advance true" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: false)
        expect(fixed_charge).to be_valid
      end
    end

    context "when charge model is volume" do
      it "returns an error with pay_in_advance true" do
        fixed_charge = build(:fixed_charge, :volume, pay_in_advance: true)

        expect(fixed_charge).not_to be_valid
        expect(fixed_charge.errors.messages[:pay_in_advance]).to include("invalid_charge_model")
      end

      it "is valid with pay_in_advance false" do
        fixed_charge = build(:fixed_charge, :volume, pay_in_advance: false)
        expect(fixed_charge).to be_valid
      end
    end

    context "when charge model is graduated" do
      it "is valid with pay_in_advance true" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: false)
        expect(fixed_charge).to be_valid
      end
    end
  end

  describe "#validate_prorated" do
    context "when charge model is standard" do
      it "is valid with pay_in_advance true and prorated true" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: true, prorated: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance true and prorated false" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: true, prorated: false)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false and prorated true" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: false, prorated: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false and prorated false" do
        fixed_charge = build(:fixed_charge, charge_model: "standard", pay_in_advance: false, prorated: false)
        expect(fixed_charge).to be_valid
      end
    end

    context "when charge model is volume" do
      it "is valid with pay_in_advance false and prorated true" do
        fixed_charge = build(:fixed_charge, :volume, pay_in_advance: false, prorated: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false and prorated false" do
        fixed_charge = build(:fixed_charge, :volume, pay_in_advance: false, prorated: false)
        expect(fixed_charge).to be_valid
      end
    end

    context "when charge model is graduated" do
      it "returns an error with pay_in_advance true and prorated true" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: true, prorated: true)

        expect(fixed_charge).not_to be_valid
        expect(fixed_charge.errors.messages[:prorated]).to include("invalid_charge_model")
      end

      it "is valid with pay_in_advance true and prorated false" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: true, prorated: false)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false and prorated true" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: false, prorated: true)
        expect(fixed_charge).to be_valid
      end

      it "is valid with pay_in_advance false and prorated false" do
        fixed_charge = build(:fixed_charge, :graduated, pay_in_advance: false, prorated: false)
        expect(fixed_charge).to be_valid
      end
    end
  end

  describe "#matching_fixed_charge_prev_subscription" do
    let(:add_on) { build(:add_on) }
    let(:fixed_charge) { build(:fixed_charge, add_on:) }
    let(:previous_subscription) { create(:subscription) }
    let(:subscription) { create(:subscription, plan: fixed_charge.plan, previous_subscription:) }

    context "when the fixed charge is included in the previous subscription" do
      before { previous_subscription.plan.fixed_charges = [fixed_charge] }

      it "returns the fixed charge" do
        expect(fixed_charge.matching_fixed_charge_prev_subscription(subscription)).to eq(fixed_charge)
      end
    end

    context "when the fixed charge is not included in the previous subscription" do
      it "returns nil" do
        expect(fixed_charge.matching_fixed_charge_prev_subscription(subscription)).to be nil
      end
    end

    context "when there is no previous subscription" do
      let(:previous_subscription) { nil }

      it "returns nil" do
        expect(fixed_charge.matching_fixed_charge_prev_subscription(subscription)).to be nil
      end
    end
  end

  describe "#effective_units_for" do
    subject(:effective_units_for) { fixed_charge.effective_units_for(subscription) }

    let(:fixed_charge) { create(:fixed_charge, units: 7) }
    let(:subscription) { create(:subscription, plan: fixed_charge.plan) }

    context "when no override exists" do
      it { is_expected.to eq(7) }
    end

    context "when subscription is nil" do
      let(:subscription) { nil }

      before do
        allow(fixed_charge).to receive(:subscription_units_overrides)
      end

      it "returns the fixed charge units without hitting the overrides table" do
        expect(effective_units_for).to eq(7)
        expect(fixed_charge).not_to have_received(:subscription_units_overrides)
      end
    end

    context "when an override exists for the (subscription, fixed_charge) pair" do
      before { create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, units: 42) }

      it { is_expected.to eq(42) }
    end

    context "when the override has been discarded" do
      before do
        override = create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, units: 42)
        override.discard!
      end

      it "falls back to the fixed charge units" do
        expect(effective_units_for).to eq(7)
      end
    end

    context "when an override exists for a different subscription" do
      before do
        other_subscription = create(:subscription, plan: fixed_charge.plan)
        create(:subscription_fixed_charge_units_override, subscription: other_subscription, fixed_charge:, units: 42)
      end

      it { is_expected.to eq(7) }
    end
  end
end
