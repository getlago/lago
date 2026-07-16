# frozen_string_literal: true

require "rails_helper"

RSpec.describe PricingUnits::CreateService do
  describe "#call" do
    subject(:result) { described_class.call(params) }

    let(:organization) { create(:organization) }
    let(:name) { "Cloud tokens" }
    let(:short_name) { "CT" }
    let(:description) { "description" }
    let(:already_used_code) { "credits" }

    let(:params) do
      {
        organization:,
        name:,
        code:,
        short_name:,
        description:
      }
    end

    before { create(:pricing_unit, code: already_used_code, organization:) }

    context "with premium organization", :premium do
      context "when params are valid" do
        let(:code) { "tokens" }

        it "returns a successful result with the pricing unit" do
          expect(result).to be_success

          expect(result.pricing_unit)
            .to be_a(PricingUnit)
            .and have_attributes(params)
        end

        it "creates pricing unit" do
          expect { result }.to change(PricingUnit, :count).by(1)
        end
      end

      context "when params are invalid" do
        let(:code) { already_used_code }

        it "fails with validation error" do
          expect(result).to be_failure
          expect(result.error.messages).to match(code: ["value_already_exist"])
        end

        it "does not create pricing unit" do
          expect { result }.not_to change(PricingUnit, :count)
        end
      end
    end

    context "with freemium organization" do
      context "when params are valid" do
        let(:code) { "tokens" }

        it "fails with a forbidden error" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
          expect(result.error.code).to eq("feature_unavailable")
        end

        it "does not create pricing unit" do
          expect { result }.not_to change(PricingUnit, :count)
        end
      end

      context "when params are invalid" do
        let(:code) { already_used_code }

        it "fails with a forbidden error" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
          expect(result.error.code).to eq("feature_unavailable")
        end

        it "does not create pricing unit" do
          expect { result }.not_to change(PricingUnit, :count)
        end
      end
    end
  end
end
