# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Entitlement::FeatureSerializer do
  subject { described_class.new(feature) }

  let(:organization) { create(:organization) }
  let(:feature) do
    create(:feature,
      organization:,
      code: "seats",
      name: "Number of seats",
      description: "Number of users of the account")
  end
  let(:max_admins) { create(:privilege, feature:, code: "max_admins", value_type: "integer") }
  let(:max) { create(:privilege, feature:, code: "max", name: "Maximum", value_type: "integer") }

  before do
    max
    max_admins
  end

  describe "#serialize" do
    it "serializes the feature with privileges" do
      result = subject.serialize

      expect(result).to include(
        code: "seats",
        name: "Number of seats",
        description: "Number of users of the account",
        created_at: feature.created_at.iso8601
      )

      expect(result[:privileges]).to contain_exactly(
        {
          code: "max_admins",
          name: nil,
          value_type: "integer",
          config: {}
        },
        {
          code: "max",
          name: "Maximum",
          value_type: "integer",
          config: {}
        }
      )
    end

    it "includes all required fields" do
      result = subject.serialize

      expect(result.keys).to match_array([:code, :name, :description, :privileges, :created_at])
    end

    it "formats created_at as ISO8601" do
      result = subject.serialize

      expect(result[:created_at]).to eq(feature.created_at.iso8601)
    end

    context "when feature has no privileges" do
      subject { described_class.new(feature_without_privileges) }

      let(:feature_without_privileges) do
        create(:feature,
          organization:,
          code: "no_privileges",
          name: "No Privileges",
          description: "Feature without privileges")
      end

      it "returns empty privileges hash" do
        result = subject.serialize

        expect(result[:privileges]).to eq([])
      end
    end
  end
end
