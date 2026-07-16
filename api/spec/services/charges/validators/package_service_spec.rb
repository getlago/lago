# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::Validators::PackageService do
  subject(:validation_service) { described_class.new(charge:) }

  let(:charge) { build(:package_charge, properties: package_properties) }

  let(:package_properties) do
    {
      package_size: 10,
      free_units: 10,
      amount: "100"
    }
  end

  describe ".valid?" do
    it { expect(validation_service).to be_valid }

    context "without amount" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: 10
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:amount)
        expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
      end
    end

    context "when amount is not numeric" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: 10,
          amount: "foo"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:amount)
        expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
      end
    end

    context "with negative amount" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: 10,
          amount: "-3"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:amount)
        expect(validation_service.result.error.messages[:amount]).to include("invalid_amount")
      end
    end

    context "without package size" do
      let(:package_properties) do
        {
          free_units: 10,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:package_size)
        expect(validation_service.result.error.messages[:package_size]).to include("invalid_package_size")
      end
    end

    context "when package size is not numeric" do
      let(:package_properties) do
        {
          package_size: "foo",
          free_units: 10,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:package_size)
        expect(validation_service.result.error.messages[:package_size]).to include("invalid_package_size")
      end
    end

    context "with negative package size" do
      let(:package_properties) do
        {
          package_size: -3,
          free_units: 10,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:package_size)
        expect(validation_service.result.error.messages[:package_size]).to include("invalid_package_size")
      end
    end

    context "with zero package size" do
      let(:package_properties) do
        {
          package_size: 0,
          free_units: 10,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:package_size)
        expect(validation_service.result.error.messages[:package_size]).to include("invalid_package_size")
      end
    end

    context "without free units size" do
      let(:package_properties) do
        {
          package_size: 10,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:free_units)
        expect(validation_service.result.error.messages[:free_units]).to include("invalid_free_units")
      end
    end

    context "when free units are not numeric" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: "foo",
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:free_units)
        expect(validation_service.result.error.messages[:free_units]).to include("invalid_free_units")
      end
    end

    context "with negative free units" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: -3,
          amount: "100"
        }
      end

      it "is invalid" do
        expect(validation_service).not_to be_valid
        expect(validation_service.result.error).to be_a(BaseService::ValidationFailure)
        expect(validation_service.result.error.messages.keys).to include(:free_units)
        expect(validation_service.result.error.messages[:free_units]).to include("invalid_free_units")
      end
    end

    it_behaves_like "pricing_group_keys property validation" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: 10,
          amount: "100"
        }.merge(grouping_properties)
      end
    end

    it_behaves_like "presentation_group_keys property validation" do
      let(:package_properties) do
        {
          package_size: 10,
          free_units: 10,
          amount: "100"
        }.merge(grouping_properties)
      end
    end
  end
end
