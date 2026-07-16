# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::FilterPropertiesService do
  subject(:filter_service) { described_class.new(chargeable:, properties:) }

  let(:properties) { {"amount" => 100} }

  describe "#call" do
    context "with a charge" do
      let(:chargeable) { build(:charge, charge_model: "standard") }

      before do
        allow(ChargeModels::FilterProperties::ChargeService)
          .to receive(:call)
          .and_call_original
      end

      it "delegates to ChargeService" do
        filter_service.call

        expect(ChargeModels::FilterProperties::ChargeService)
          .to have_received(:call)
          .with(chargeable:, properties:)
      end

      it "returns filtered properties" do
        result = filter_service.call

        expect(result.properties).to eq(properties)
      end
    end

    context "with a fixed charge" do
      let(:chargeable) { build(:fixed_charge, charge_model: "standard") }

      before do
        allow(ChargeModels::FilterProperties::FixedChargeService)
          .to receive(:call)
          .and_call_original
      end

      it "delegates to FixedChargeService" do
        filter_service.call

        expect(ChargeModels::FilterProperties::FixedChargeService)
          .to have_received(:call)
          .with(chargeable:, properties:)
      end

      it "returns filtered properties" do
        result = filter_service.call

        expect(result.properties).to eq(properties)
      end
    end

    context "with an unsupported resource" do
      let(:chargeable) { Object.new }

      it "raises ArgumentError" do
        expect { filter_service.call }.to raise_error(ArgumentError, "Unsupported chargeable type: Object")
      end
    end
  end
end
