# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::Entitlement do
  subject(:utils_entitlement) { described_class }

  describe ".cast_value" do
    context "when value is blank" do
      it "returns nil for empty string" do
        expect(utils_entitlement.cast_value("", "integer")).to eq 0
      end

      it "returns nil for nil" do
        expect(utils_entitlement.cast_value(nil, "integer")).to be_nil
      end
    end

    context "when type is integer" do
      it "casts string to integer" do
        expect(utils_entitlement.cast_value("42", "integer")).to eq(42)
      end

      it "casts float string to integer" do
        expect(utils_entitlement.cast_value("42.5", "integer")).to eq(42)
      end
    end

    context "when type is boolean" do
      it "casts true string to boolean" do
        expect(utils_entitlement.cast_value("true", "boolean")).to be(true)
      end

      it "casts false string to boolean" do
        expect(utils_entitlement.cast_value("false", "boolean")).to be(false)
      end

      it "casts false to boolean" do
        expect(utils_entitlement.cast_value(false, "boolean")).to be(false)
      end

      it "casts 1 to boolean" do
        expect(utils_entitlement.cast_value("1", "boolean")).to be(true)
      end

      it "casts 0 to boolean" do
        expect(utils_entitlement.cast_value("0", "boolean")).to be(false)
      end
    end

    context "when type is string or unknown" do
      it "returns value as-is for string type" do
        expect(utils_entitlement.cast_value("hello", "string")).to eq("hello")
      end

      it "returns value as-is for unknown type" do
        expect(utils_entitlement.cast_value("hello", "unknown")).to eq("hello")
      end
    end
  end

  describe ".same_value?" do
    it do
      expect(utils_entitlement.same_value?("boolean", "t", true)).to eq true
      expect(utils_entitlement.same_value?("boolean", "t", "true")).to eq true
      expect(utils_entitlement.same_value?("boolean", "t", 1)).to eq true
      expect(utils_entitlement.same_value?("boolean", "t", "1")).to eq true
      expect(utils_entitlement.same_value?("boolean", "f", false)).to eq true
      expect(utils_entitlement.same_value?("boolean", "f", "false")).to eq true
      expect(utils_entitlement.same_value?("boolean", "f", 0)).to eq true
      expect(utils_entitlement.same_value?("boolean", "f", "0")).to eq true

      expect(utils_entitlement.same_value?("integer", "1", 1)).to eq true
      expect(utils_entitlement.same_value?("integer", "any", "0")).to eq true

      expect(utils_entitlement.same_value?("string", "str", "str")).to eq true
      expect(utils_entitlement.same_value?("string", "str", "str2")).to eq false

      # Notice that the same values with "boolean" would be considered equal
      expect(utils_entitlement.same_value?("string", "f", "0")).to eq false
    end
  end

  describe ".convert_gql_input_to_params" do
    context "when entitlements array is empty" do
      it "returns an empty hash" do
        result = utils_entitlement.convert_gql_input_to_params([])
        expect(result).to eq({})
      end
    end

    context "when multiple entitlements are provided" do
      let(:entitlement1) do
        instance_double(::Types::Entitlement::EntitlementInput,
          feature_code: "seats",
          privileges: [
            instance_double(::Types::Entitlement::EntitlementPrivilegeInput, privilege_code: "max_seats", value: 50)
          ])
      end
      let(:entitlement2) do
        instance_double(::Types::Entitlement::EntitlementInput,
          feature_code: "storage",
          privileges: [
            instance_double(::Types::Entitlement::EntitlementPrivilegeInput, privilege_code: "limit", value: "1TB"),
            instance_double(::Types::Entitlement::EntitlementPrivilegeInput, privilege_code: "enabled", value: false)
          ])
      end
      let(:entitlement3) do
        instance_double(::Types::Entitlement::EntitlementInput,
          feature_code: "api_access",
          privileges: [])
      end

      it "returns hash with all entitlements mapped correctly" do
        result = utils_entitlement.convert_gql_input_to_params([entitlement1, entitlement2, entitlement3])
        expect(result).to eq({
          "seats" => {
            "max_seats" => 50
          },
          "storage" => {
            "limit" => "1TB",
            "enabled" => false
          },
          "api_access" => {}
        })
      end
    end
  end
end
