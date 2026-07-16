# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::Validators::VolumeService do
  subject(:validation_service) { described_class.new(charge:) }

  let(:charge) { build(:volume_charge, properties:) }

  let(:properties) { {volume_ranges: ranges} }
  let(:ranges) do
    [
      {
        from_value: 0,
        to_value: 10,
        per_unit_amount: "0",
        flat_amount: "0"
      },
      {
        from_value: 11,
        to_value: 20,
        per_unit_amount: "10",
        flat_amount: "20"
      },
      {
        from_value: 21,
        to_value: nil,
        per_unit_amount: "15",
        flat_amount: "30"
      }
    ]
  end

  describe ".validate" do
    it { expect(validation_service).to be_valid }

    context "with empty ranges" do
      let(:ranges) { [] }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:volume_ranges)
        expect(validation_service.result.error.messages[:volume_ranges]).to include("missing_volume_ranges")
      end
    end

    context "when ranges does not starts at 0" do
      let(:ranges) do
        [{from_value: -1, to_value: 100}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:volume_ranges)
        expect(validation_service.result.error.messages[:volume_ranges]).to include("invalid_volume_ranges")
      end
    end

    context "when ranges does not ends at infinity" do
      let(:ranges) do
        [{from_value: 0, to_value: 100}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:volume_ranges)
        expect(validation_service.result.error.messages[:volume_ranges]).to include("invalid_volume_ranges")
      end
    end

    context "when ranges have holes" do
      let(:ranges) do
        [
          {from_value: 0, to_value: 100},
          {from_value: 120, to_value: 100}
        ]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:volume_ranges)
        expect(validation_service.result.error.messages[:volume_ranges]).to include("invalid_volume_ranges")
      end
    end

    context "when ranges are overlapping" do
      let(:ranges) do
        [
          {from_value: 0, to_value: 100},
          {from_value: 90, to_value: 100}
        ]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:volume_ranges)
        expect(validation_service.result.error.messages[:volume_ranges]).to include("invalid_volume_ranges")
      end
    end

    context "with no range per unit amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: nil, flat_amount: "0"}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:per_unit_amount)
        expect(validation_service.result.error.messages[:per_unit_amount]).to include("invalid_amount")
      end
    end

    context "with invalid range per unit amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: "foo", flat_amount: "0"}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:per_unit_amount)
        expect(validation_service.result.error.messages[:per_unit_amount]).to include("invalid_amount")
      end
    end

    context "with negative range per unit amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: "-2", flat_amount: 0}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:per_unit_amount)
        expect(validation_service.result.error.messages[:per_unit_amount]).to include("invalid_amount")
      end
    end

    context "with no range flat amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: nil}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:flat_amount)
        expect(validation_service.result.error.messages[:flat_amount]).to include("invalid_amount")
      end
    end

    context "with invalid range flat amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "foo"}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:flat_amount)
        expect(validation_service.result.error.messages[:flat_amount]).to include("invalid_amount")
      end
    end

    context "with negative range flat amount cents" do
      let(:ranges) do
        [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "-2"}]
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:flat_amount)
        expect(validation_service.result.error.messages[:flat_amount]).to include("invalid_amount")
      end
    end

    it_behaves_like "pricing_group_keys property validation" do
      let(:properties) { {"volume_ranges" => ranges}.merge(grouping_properties) }
    end

    it_behaves_like "presentation_group_keys property validation" do
      let(:properties) { {"volume_ranges" => ranges}.merge(grouping_properties) }
    end
  end
end
