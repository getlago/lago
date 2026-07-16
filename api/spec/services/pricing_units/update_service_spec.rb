# frozen_string_literal: true

require "rails_helper"

RSpec.describe PricingUnits::UpdateService do
  describe "#call" do
    subject(:result) { described_class.call(pricing_unit:, params:) }

    let(:name) { "Cloud tokens" }
    let(:short_name) { "CT" }
    let(:description) { "description" }

    let(:params) do
      {
        name:,
        short_name:,
        description:
      }
    end

    context "with premium organization", :premium do
      context "when pricing unit is present" do
        let!(:pricing_unit) { create(:pricing_unit) }

        context "when params are valid" do
          let(:description) { "description" }

          it "returns a successful result with the pricing unit" do
            expect(result).to be_success

            expect(result.pricing_unit)
              .to be_a(PricingUnit)
              .and have_attributes(params)
          end

          it "updates the pricing unit" do
            expect { result }.to change(pricing_unit, :attributes)
          end
        end

        context "when params are invalid" do
          let(:description) { "a" * 601 }

          it "fails with validation error" do
            expect(result).to be_failure
            expect(result.error.messages).to match(description: ["value_is_too_long"])
          end

          it "does not update the pricing unit" do
            expect { result }.not_to change { pricing_unit.reload.attributes }
          end
        end
      end

      context "when pricing unit is missing" do
        let(:pricing_unit) { nil }

        context "when params are valid" do
          let(:description) { "description" }

          it "fails with pricing unit not found error" do
            expect(result).to be_failure
            expect(result.error.error_code).to eq("pricing_unit_not_found")
          end
        end

        context "when params are invalid" do
          let(:description) { "a" * 601 }

          it "fails with pricing unit not found error" do
            expect(result).to be_failure
            expect(result.error.error_code).to eq("pricing_unit_not_found")
          end
        end
      end
    end

    context "with freemium organization" do
      context "when pricing unit is present" do
        let!(:pricing_unit) { create(:pricing_unit) }

        context "when params are valid" do
          let(:description) { "description" }

          it "fails with a forbidden error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ForbiddenFailure)
            expect(result.error.code).to eq("feature_unavailable")
          end

          it "does not update the pricing unit" do
            expect { result }.not_to change { pricing_unit.reload.attributes }
          end
        end

        context "when params are invalid" do
          let(:description) { "a" * 601 }

          it "fails with a forbidden error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ForbiddenFailure)
            expect(result.error.code).to eq("feature_unavailable")
          end

          it "does not update the pricing unit" do
            expect { result }.not_to change { pricing_unit.reload.attributes }
          end
        end
      end

      context "when pricing unit is missing" do
        let(:pricing_unit) { nil }

        context "when params are valid" do
          let(:description) { "description" }

          it "fails with a forbidden error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ForbiddenFailure)
            expect(result.error.code).to eq("feature_unavailable")
          end
        end

        context "when params are invalid" do
          let(:description) { "a" * 601 }

          it "fails with a forbidden error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ForbiddenFailure)
            expect(result.error.code).to eq("feature_unavailable")
          end
        end
      end
    end
  end
end
