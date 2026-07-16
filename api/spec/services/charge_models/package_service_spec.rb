# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::PackageService do
  subject(:apply_package_service) do
    described_class.apply(
      charge:,
      aggregation_result:,
      properties: charge.properties,
      period_ratio: 1.0
    )
  end

  before do
    aggregation_result.aggregation = aggregation
  end

  let(:aggregation_result) { BaseService::Result.new }
  let(:aggregation) { 121 }

  let(:charge) do
    create(
      :package_charge,
      properties: {
        amount: "100",
        package_size: 10,
        free_units: 0
      }
    )
  end

  it "applies the package size to the value" do
    expect(apply_package_service.amount).to eq(1300)
    expect(apply_package_service.unit_amount.round(2)).to eq(10.74)
    expect(apply_package_service.amount_details).to eq(
      {
        free_units: "0.0",
        paid_units: "121.0",
        per_package_size: 10,
        per_package_unit_amount: 100
      }
    )
  end

  context "with free_units" do
    before { charge.properties["free_units"] = 10 }

    it "substracts the free units from the value" do
      expect(apply_package_service.amount).to eq(1200)
      expect(apply_package_service.unit_amount.round(2)).to eq(10.81)
      expect(apply_package_service.amount_details).to eq(
        {
          free_units: "10.0",
          paid_units: "111.0",
          per_package_size: 10,
          per_package_unit_amount: 100
        }
      )
    end

    context "when free units is higher than the value" do
      before { charge.properties["free_units"] = 200 }

      it "substracts the free units from the value" do
        expect(apply_package_service.amount).to eq(0)
        expect(apply_package_service.unit_amount).to eq(0)
        expect(apply_package_service.amount_details).to eq(
          {
            free_units: "200.0",
            paid_units: "0.0",
            per_package_size: 10,
            per_package_unit_amount: 100
          }
        )
      end
    end
  end
end
