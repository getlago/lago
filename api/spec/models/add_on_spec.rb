# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOn do
  subject { build(:add_on) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:applied_add_ons) }
  it { is_expected.to have_many(:customers) }
  it { is_expected.to have_many(:fees) }
  it { is_expected.to have_many(:fixed_charges).dependent(:destroy) }
  it { is_expected.to have_many(:applied_taxes).dependent(:destroy) }
  it { is_expected.to have_many(:taxes) }
  it { is_expected.to have_many(:netsuite_mappings).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_numericality_of(:amount_cents) }
  it { is_expected.to validate_presence_of(:code) }

  describe "validations" do
    let(:errors) { add_on.errors }

    describe "of amount currency inclusion" do
      subject(:add_on) { build(:add_on, amount_currency:) }

      before { add_on.valid? }

      context "when it is one from the currency list" do
        let(:amount_currency) { "EUR" }

        it "does not add an error" do
          expect(errors.where(:amount_currency, :inclusion)).not_to be_present
        end
      end

      context "when it is not one from the currency list" do
        let(:amount_currency) { "ABC" }

        it "adds an error" do
          expect(errors.where(:amount_currency, :inclusion)).to be_present
        end
      end
    end

    describe "of code uniqueness" do
      context "when it is unique in scope of organization" do
        subject(:add_on) { build(:add_on) }

        it "does not add an error" do
          expect(errors.where(:code, :taken)).not_to be_present
        end
      end

      context "when it not is unique in scope of organization" do
        subject(:add_on) { build(:add_on, organization:, code:) }

        let(:code) { Faker::Name.name }
        let(:organization) { create(:organization) }
        let(:errors) { add_on.errors }

        before do
          create(:add_on, organization:, code:)
          add_on.valid?
        end

        it "adds an error" do
          expect(errors.where(:code, :taken)).to be_present
        end
      end
    end
  end

  describe "#invoice_name" do
    subject(:add_on_invoice_name) { add_on.invoice_name }

    context "when invoice display name is blank" do
      let(:add_on) { build_stubbed(:add_on, invoice_display_name: [nil, ""].sample) }

      it "returns name" do
        expect(add_on_invoice_name).to eq(add_on.name)
      end
    end

    context "when invoice display name is present" do
      let(:add_on) { build_stubbed(:add_on) }

      it "returns invoice display name" do
        expect(add_on_invoice_name).to eq(add_on.invoice_display_name)
      end
    end
  end
end
