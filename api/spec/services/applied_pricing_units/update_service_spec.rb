# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedPricingUnits::UpdateService do
  let(:update_service) { described_class.new(charge:, cascade_options:, params:) }

  describe ".call" do
    subject(:result) { update_service.call }

    context "when charge is missing" do
      let(:charge) { nil }
      let(:cascade_options) { {} }
      let(:params) { {} }

      it "fails with charge not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("charge_not_found")
      end
    end

    context "when charge is present" do
      let(:charge) { create(:standard_charge) }

      context "when charge has no applied pricing unit associated" do
        let(:cascade_options) { {} }
        let(:params) { {} }

        it "return empty result" do
          expect(result).to be_success
        end
      end

      context "when charge has applied pricing unit associated" do
        let(:cascade_options) { {cascade: true, equal_applied_pricing_unit_rate:} }
        let(:params) { {conversion_rate:} }

        let!(:applied_pricing_unit) do
          create(:applied_pricing_unit, pricing_unitable: charge, conversion_rate: 1)
        end

        context "when applied pricing unit should be updated" do
          let(:equal_applied_pricing_unit_rate) { true }

          context "when params are valid" do
            let(:conversion_rate) { 1.5 }

            it "updates applied pricing unit's rate" do
              expect { subject }
                .to change { applied_pricing_unit.reload.conversion_rate }
                .to(conversion_rate)
            end
          end

          context "when params are invalid" do
            let(:conversion_rate) { -1 }

            it "fails with validation error" do
              expect(result).to be_failure
              expect(result.error.messages).to match(conversion_rate: ["value_is_out_of_range"])
            end

            it "does not update applied pricing unit's rate" do
              expect { subject }.not_to change { applied_pricing_unit.reload.conversion_rate }
            end
          end
        end

        context "when applied pricing unit should not be updated" do
          let(:equal_applied_pricing_unit_rate) { false }

          context "when params are valid" do
            let(:conversion_rate) { 1.5 }

            it "does not update applied pricing unit's rate" do
              expect { subject }.not_to change { applied_pricing_unit.reload.conversion_rate }
            end
          end

          context "when params are invalid" do
            let(:conversion_rate) { -1 }

            it "does not update applied pricing unit's rate" do
              expect { subject }.not_to change { applied_pricing_unit.reload.conversion_rate }
            end
          end
        end
      end
    end
  end

  describe "#update_conversion_rate?" do
    subject { update_service.update_conversion_rate? }

    let(:charge) { create(:applied_pricing_unit).pricing_unitable }
    let(:cascade_options) { {cascade:, equal_applied_pricing_unit_rate:} }

    context "when params are present" do
      let(:params) { {conversion_rate: rand(0.5..10)} }

      context "when cascade is true" do
        let(:cascade) { true }

        context "when cascade equal conversion rate is true" do
          let(:equal_applied_pricing_unit_rate) { true }

          it "returns true" do
            expect(subject).to be true
          end
        end

        context "when cascade equal conversion rate is false" do
          let(:equal_applied_pricing_unit_rate) { false }

          it "returns false" do
            expect(subject).to be false
          end
        end
      end

      context "when cascade is false" do
        let(:cascade) { false }

        context "when cascade equal conversion rate is true" do
          let(:equal_applied_pricing_unit_rate) { true }

          it "returns true" do
            expect(subject).to be true
          end
        end

        context "when cascade equal conversion rate is false" do
          let(:equal_applied_pricing_unit_rate) { false }

          it "returns true" do
            expect(subject).to be true
          end
        end
      end
    end

    context "when params are missing" do
      let(:params) { {} }

      context "when cascade is true" do
        let(:cascade) { true }

        context "when cascade equal conversion rate is true" do
          let(:equal_applied_pricing_unit_rate) { true }

          it "returns false" do
            expect(subject).to be false
          end
        end

        context "when cascade equal conversion rate is false" do
          let(:equal_applied_pricing_unit_rate) { false }

          it "returns false" do
            expect(subject).to be false
          end
        end
      end

      context "when cascade is false" do
        let(:cascade) { false }

        context "when cascade equal conversion rate is true" do
          let(:equal_applied_pricing_unit_rate) { true }

          it "returns false" do
            expect(subject).to be false
          end
        end

        context "when cascade equal conversion rate is false" do
          let(:equal_applied_pricing_unit_rate) { false }

          it "returns false" do
            expect(subject).to be false
          end
        end
      end
    end
  end
end
