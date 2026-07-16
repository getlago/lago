# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::Factory do
  subject(:factory) { described_class }

  let(:charge) { build(:standard_charge) }

  describe "#new_instance" do
    let(:aggregation_result) { BaseService::Result.new }
    let(:properties) { charge.properties }

    let(:result) { factory.new_instance(chargeable: charge, aggregation_result:, properties:) }

    context "when chargeable is not a charge or a fixed charge" do
      let(:chargeable) { build(:fee) }

      it "raises an error" do
        expect { factory.new_instance(chargeable:, aggregation_result:, properties:) }.to raise_error(NotImplementedError)
      end
    end

    context "when chargeable is a charge" do
      context "with standard charge model" do
        it { expect(result).to be_a(ChargeModels::StandardService) }

        context "when charge is grouped" do
          let(:charge) { build(:standard_charge, properties: {grouped_by: ["cloud"]}) }
          let(:aggregation_result) { BaseService::Result.new.tap { |r| r.aggregations = [BaseService::Result.new] } }

          it { expect(result).to be_a(ChargeModels::GroupedService) }
        end

        context "when charge accepts target wallet" do
          let(:charge) { build(:standard_charge, accepts_target_wallet: true) }
          let(:aggregation_result) { BaseService::Result.new.tap { |r| r.aggregations = [BaseService::Result.new] } }

          it { expect(result).to be_a(ChargeModels::GroupedService) }
        end
      end

      context "with graduated charge model" do
        let(:charge) { build(:graduated_charge) }

        it { expect(result).to be_a(ChargeModels::GraduatedService) }

        context "when charge is prorated" do
          let(:charge) { build(:graduated_charge, prorated: true) }
          let(:aggregation_result) { BaseService::Result.new.tap { |r| r.aggregator = [BaseService::Result.new] } }

          it { expect(result).to be_a(ChargeModels::ProratedGraduatedService) }
        end

        context "when charge is prorated, but we are forecasting amounts" do
          let(:charge) { build(:graduated_charge, prorated: true) }

          it { expect(result).to be_a(ChargeModels::GraduatedService) }
        end
      end

      context "with graduated_percentage charge model" do
        let(:charge) { build(:graduated_percentage_charge) }

        it { expect(result).to be_a(ChargeModels::GraduatedPercentageService) }
      end

      context "with package charge model" do
        let(:charge) { build(:package_charge) }

        it { expect(result).to be_a(ChargeModels::PackageService) }
      end

      context "with percentage charge model" do
        let(:charge) { build(:percentage_charge) }

        it { expect(result).to be_a(ChargeModels::PercentageService) }
      end

      context "with volume charge model" do
        let(:charge) { build(:volume_charge) }

        it { expect(result).to be_a(ChargeModels::VolumeService) }
      end

      context "with dynamic charge model" do
        let(:charge) { build(:dynamic_charge) }

        it { expect(result).to be_a(ChargeModels::DynamicService) }
      end

      context "with custom charge model" do
        let(:charge) { build(:custom_charge) }

        it { expect(result).to be_a(ChargeModels::CustomService) }
      end
    end

    context "when chargeable is a fixed charge" do
      context "with standard charge model" do
        let(:charge) { build(:fixed_charge, charge_model: :standard) }

        it { expect(result).to be_a(ChargeModels::StandardService) }
      end

      context "with graduated charge model" do
        let(:charge) { build(:fixed_charge, charge_model: :graduated) }

        it { expect(result).to be_a(ChargeModels::GraduatedService) }
      end

      context "with volume charge model" do
        let(:charge) { build(:fixed_charge, charge_model: :volume) }

        it { expect(result).to be_a(ChargeModels::VolumeService) }
      end
    end
  end

  describe ".in_advance_charge_model_class" do
    let(:result) { factory.in_advance_charge_model_class(chargeable: charge) }

    context "when chargeable is a charge" do
      context "with standard charge model" do
        it { expect(result).to eq(ChargeModels::StandardService) }
      end

      context "with graduated charge model" do
        let(:charge) { build(:graduated_charge) }

        it { expect(result).to eq(ChargeModels::GraduatedService) }
      end

      context "with graduated_percentage charge model" do
        let(:charge) { build(:graduated_percentage_charge) }

        it { expect(result).to eq(ChargeModels::GraduatedPercentageService) }
      end

      context "with package charge model" do
        let(:charge) { build(:package_charge) }

        it { expect(result).to eq(ChargeModels::PackageService) }
      end

      context "with percentage charge model" do
        let(:charge) { build(:percentage_charge) }

        it { expect(result).to eq(ChargeModels::PercentageService) }
      end

      context "with volume charge model" do
        let(:charge) { build(:volume_charge) }

        it { expect { result }.to raise_error(NotImplementedError) }
      end

      context "with dynamic charge model" do
        let(:charge) { build(:dynamic_charge) }

        it { expect(result).to eq(ChargeModels::DynamicService) }
      end

      context "with custom charge model" do
        let(:charge) { build(:custom_charge) }

        it { expect(result).to eq(ChargeModels::CustomService) }
      end
    end
  end
end
