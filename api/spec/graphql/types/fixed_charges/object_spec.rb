# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::FixedCharges::Object do
  subject { described_class }

  it { is_expected.to have_field(:code).of_type("String") }
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:invoice_display_name).of_type("String") }
  it { is_expected.to have_field(:parent_id).of_type("ID") }

  it { is_expected.to have_field(:add_on).of_type("AddOn!") }
  it { is_expected.to have_field(:charge_model).of_type("FixedChargeChargeModelEnum!") }
  it { is_expected.to have_field(:pay_in_advance).of_type("Boolean!") }
  it { is_expected.to have_field(:properties).of_type("FixedChargeProperties") }
  it { is_expected.to have_field(:prorated).of_type("Boolean!") }
  it { is_expected.to have_field(:units).of_type("String!") }

  it { is_expected.to have_field(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:deleted_at).of_type("ISO8601DateTime") }
  it { is_expected.to have_field(:updated_at).of_type("ISO8601DateTime!") }

  it { is_expected.to have_field(:taxes).of_type("[Tax!]") }

  describe "#units" do
    subject { run_graphql_field("FixedCharge.units", fixed_charge) }

    context "when units is a whole number" do
      let(:fixed_charge) { create(:fixed_charge, units: 1.0) }

      it "returns the value without decimal point" do
        expect(subject).to eq("1")
      end
    end

    context "when units has decimal places" do
      let(:fixed_charge) { create(:fixed_charge, units: 1.5) }

      it "returns the value with decimal places" do
        expect(subject).to eq("1.5")
      end
    end

    context "when units is zero" do
      let(:fixed_charge) { create(:fixed_charge, units: 0.0) }

      it "returns zero without decimal point" do
        expect(subject).to eq("0")
      end
    end

    context "when units has trailing zeros" do
      let(:fixed_charge) { create(:fixed_charge, units: 2.5000) }

      it "returns the value without trailing zeros" do
        expect(subject).to eq("2.5")
      end
    end
  end
end
