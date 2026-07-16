# frozen_string_literal: true

RSpec.shared_examples "presentation_group_keys property validation" do
  let(:grouping_properties) { {"presentation_group_keys" => presentation_group_keys} }
  let(:presentation_group_keys) { nil }

  it { expect(validation_service).to be_valid }

  context "when presentation_group_keys is an empty array" do
    let(:presentation_group_keys) { [] }

    it "is valid" do
      expect(validation_service).to be_valid
    end
  end

  context "when presentation_group_keys is valid with 1 element" do
    let(:presentation_group_keys) { [{"value" => "region"}] }

    it "is valid" do
      expect(validation_service).to be_valid
    end
  end

  context "when presentation_group_keys is valid with 2 elements" do
    let(:presentation_group_keys) { [{"value" => "region"}, {"value" => "country"}] }

    it "is valid" do
      expect(validation_service).to be_valid
    end
  end

  context "when presentation_group_keys has duplicated values" do
    let(:presentation_group_keys) { [{"value" => "country"}, {"value" => "country"}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("value_is_duplicated")
    end
  end

  context "when presentation_group_keys has options" do
    let(:presentation_group_keys) do
      [
        {"value" => "region", "options" => {"display_in_invoice" => true}},
        {"value" => "country", "options" => {"display_in_invoice" => false}}
      ]
    end

    it "is valid" do
      expect(validation_service).to be_valid
    end
  end

  context "when presentation_group_keys has options with non-hash value" do
    let(:presentation_group_keys) { [{"value" => "region", "options" => "invalid"}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys has options with unknown key" do
    let(:presentation_group_keys) { [{"value" => "region", "options" => {"unknown" => true}}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys has options with extra keys" do
    let(:presentation_group_keys) do
      [{"value" => "region", "options" => {"display_in_invoice" => true, "extra" => false}}]
    end

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys has options with non-boolean display_in_invoice" do
    let(:presentation_group_keys) { [{"value" => "region", "options" => {"display_in_invoice" => "true"}}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys has more than 2 elements" do
    let(:presentation_group_keys) do
      [
        {"value" => "region"},
        {"value" => "country"},
        {"value" => "city"}
      ]
    end

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("too_many_keys")
    end
  end

  context "when presentation_group_keys is not an array" do
    let(:presentation_group_keys) { "not_an_array" }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains non-hash elements" do
    let(:presentation_group_keys) { ["region", "country"] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains hashes without 'value' key" do
    let(:presentation_group_keys) { [{"key" => "region"}, {"value" => "country"}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains hashes with nil value" do
    let(:presentation_group_keys) { [{"value" => nil}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains hashes with empty string value" do
    let(:presentation_group_keys) { [{"value" => ""}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains hashes with numeric value" do
    let(:presentation_group_keys) { [{"value" => 123}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end

  context "when presentation_group_keys contains hashes with extra keys" do
    let(:presentation_group_keys) { [{"value" => "region", "extra" => "nope"}] }

    it "is invalid" do
      expect(validation_service).not_to be_valid
      expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
      expect(validation_service.result.error.messages.keys).to include(:presentation_group_keys)
      expect(validation_service.result.error.messages[:presentation_group_keys]).to include("invalid_type")
    end
  end
end
