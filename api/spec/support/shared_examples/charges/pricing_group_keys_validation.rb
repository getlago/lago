# frozen_string_literal: true

RSpec.shared_examples "pricing_group_keys property validation" do
  let(:grouping_properties) { {"pricing_group_keys" => pricing_group_keys} }
  let(:pricing_group_keys) { [] }

  it { expect(validation_service).to be_valid }

  context "when attribute is not an array" do
    let(:pricing_group_keys) { "group" }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:pricing_group_keys)
      expect(validation_service.result.error.messages[:pricing_group_keys]).to include("invalid_type")
    end
  end

  context "when attribute is not a list of string" do
    let(:pricing_group_keys) { [12, 45] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:pricing_group_keys)
      expect(validation_service.result.error.messages[:pricing_group_keys]).to include("invalid_type")
    end
  end

  context "when attribute is an empty string" do
    let(:pricing_group_keys) { "" }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:pricing_group_keys)
      expect(validation_service.result.error.messages[:pricing_group_keys]).to include("invalid_type")
    end
  end

  context "when using legacy grouped_by property" do
    let(:grouping_properties) { {"grouped_by" => grouped_by} }
    let(:grouped_by) { [] }

    it { expect(validation_service).to be_valid }

    context "when attribute is not an array" do
      let(:grouped_by) { "group" }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:grouped_by)
        expect(validation_service.result.error.messages[:grouped_by]).to include("invalid_type")
      end
    end

    context "when attribute is not a list of string" do
      let(:grouped_by) { [12, 45] }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:grouped_by)
        expect(validation_service.result.error.messages[:grouped_by]).to include("invalid_type")
      end
    end

    context "when attribute is an empty string" do
      let(:grouped_by) { "" }

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:grouped_by)
        expect(validation_service.result.error.messages[:grouped_by]).to include("invalid_type")
      end
    end
  end
end
