# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedPricingUnits::CreateService do
  let(:create_service) { described_class.new(charge:, params:) }

  describe "#create_applied_pricing_unit?" do
    subject { create_service.create_applied_pricing_unit? }

    let(:charge) { build_stubbed(:standard_charge) }

    context "when premium", :premium do
      context "when params are present" do
        let(:params) { {code: "credits", conversion_rate: 1.5} }

        it "returns true" do
          expect(subject).to be true
        end
      end

      context "when params are missing" do
        let(:params) { {} }

        it "returns false" do
          expect(subject).to be false
        end
      end
    end

    context "when freemium" do
      context "when params are present" do
        let(:params) { {code: "credits", conversion_rate: 1.5} }

        it "returns false" do
          expect(subject).to be false
        end
      end

      context "when params are missing" do
        let(:params) { {} }

        it "returns false" do
          expect(subject).to be false
        end
      end
    end
  end

  describe "#call" do
    subject(:result) { create_service.call }

    context "when charge is missing" do
      let(:charge) { nil }
      let(:params) { {} }

      it "fails with charge not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("charge_not_found")
      end

      it "does not create applied pricing unit" do
        expect { subject }.not_to change(AppliedPricingUnit, :count)
      end
    end

    context "when charge is present" do
      let(:organization) { create(:organization) }
      let(:charge) { create(:standard_charge, organization:) }

      context "when applied pricing unit should not be created" do
        let(:params) { {} }

        it "does not create applied pricing unit and return empty result" do
          expect { subject }.not_to change(AppliedPricingUnit, :count)
          expect(result).to be_success
        end
      end

      context "when applied pricing unit should be created", :premium do
        let!(:pricing_unit) { create(:pricing_unit, organization:) }

        context "when params are valid" do
          let(:params) { {code: pricing_unit.code, conversion_rate: 1.5} }

          it "creates an applied pricing unit" do
            expect { subject }
              .to change { charge.reload.applied_pricing_unit }
              .to(AppliedPricingUnit)
          end

          it "sets the correct attributes" do
            applied_pricing_unit = result.charge.applied_pricing_unit
            expect(applied_pricing_unit.pricing_unit).to eq(pricing_unit)
            expect(applied_pricing_unit.organization).to eq(organization)
            expect(applied_pricing_unit.conversion_rate).to eq(1.5)
          end
        end

        context "when params are invalid" do
          let(:params) { {code: "non-existing-code", conversion_rate: -1} }

          it "fails with validation error" do
            expect(result).to be_failure

            expect(result.error.messages).to match(
              conversion_rate: ["value_is_out_of_range"],
              pricing_unit: ["relation_must_exist"]
            )
          end

          it "does not create an applied pricing unit" do
            expect { subject }.not_to change(AppliedPricingUnit, :count)
          end
        end
      end
    end
  end
end
