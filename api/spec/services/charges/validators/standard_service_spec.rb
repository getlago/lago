# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::Validators::StandardService do
  subject(:validation_service) { described_class.new(charge:) }

  let(:charge) { build(:standard_charge, properties:) }
  let(:properties) { {} }

  describe ".valid?" do
    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:amount)
      expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
    end

    context "when amount is not an integer" do
      let(:properties) { {amount: "Foo"} }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:amount)
        expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
      end
    end

    context "when amount is negative" do
      let(:properties) { {amount: "-12"} }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:amount)
        expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
      end
    end

    context "with an applicable amount" do
      let(:properties) { {amount: "12"} }

      it { expect(validation_service).to be_valid }
    end

    it_behaves_like "pricing_group_keys property validation" do
      let(:properties) { {"amount" => "12"}.merge(grouping_properties) }
    end

    it_behaves_like "presentation_group_keys property validation" do
      let(:properties) { {"amount" => "12"}.merge(grouping_properties) }
    end
  end
end
