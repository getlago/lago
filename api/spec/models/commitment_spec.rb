# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitment do
  it { is_expected.to belong_to(:plan) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:applied_taxes).dependent(:destroy) }
  it { is_expected.to have_many(:taxes) }

  it { is_expected.to validate_numericality_of(:amount_cents) }

  describe "#invoice_name" do
    subject(:commitment_invoice_name) { commitment.invoice_name }

    context "when invoice display name is blank" do
      let(:commitment) { build_stubbed(:commitment, invoice_display_name: [nil, ""].sample) }

      it "returns name" do
        expect(commitment_invoice_name).to eq("Minimum commitment")
      end
    end

    context "when invoice display name is present" do
      let(:commitment) { build_stubbed(:commitment) }

      it "returns invoice display name" do
        expect(commitment_invoice_name).to eq(commitment.invoice_display_name)
      end
    end
  end

  describe "validations" do
    subject(:commitment) { build(:commitment) }

    describe "of commitment type uniqueness" do
      let(:errors) { commitment.errors }

      context "when it is unique in scope of plan" do
        it "does not add an error" do
          expect(errors.where(:commitment_type, :taken)).not_to be_present
        end
      end

      context "when it not is unique in scope of plan" do
        subject(:commitment) do
          build(:commitment, plan:)
        end

        let(:plan) { create(:plan) }
        let(:errors) { commitment.errors }

        before do
          create(:commitment, plan:)
          commitment.valid?
        end

        it "adds an error" do
          expect(errors.where(:commitment_type, :taken)).to be_present
        end
      end
    end
  end
end
