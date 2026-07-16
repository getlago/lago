# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Entitlement::PlanEntitlementSerializer do
  subject { described_class.new(entitlement) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, :integer_type, feature:, organization:) }
  let(:privilege2) { create(:privilege, :boolean_type, feature:, organization:) }
  let(:privilege3) { create(:privilege, :string_type, feature:, organization:) }
  let(:privilege4) { create(:privilege, :select_type, feature:, organization:) }

  let(:entitlement) { create(:entitlement, organization:, feature:, plan:) }
  let(:entitlement_value) { create(:entitlement_value, value: "30", entitlement:, privilege:, organization:) }
  let(:entitlement_value2) { create(:entitlement_value, value: "false", entitlement:, privilege: privilege2, organization:) }
  let(:entitlement_value3) { create(:entitlement_value, value: :str, entitlement:, privilege: privilege3, organization:) }
  let(:entitlement_value4) { create(:entitlement_value, value: "option1", entitlement:, privilege: privilege4, organization:) }

  describe "#serialize" do
    before do
      entitlement_value
      entitlement_value2
      entitlement_value3
      entitlement_value4
    end

    it "serializes the entitlement correctly" do
      result = subject.serialize

      expect(result).to include(
        code: "seats",
        name: feature.name,
        description: feature.description
      )
      expect(result[:privileges]).to contain_exactly(
        {code: "int", name: nil, value_type: "integer", value: 30, config: {}},
        {code: "bool", name: nil, value_type: "boolean", value: false, config: {}},
        {code: "str", name: nil, value_type: "string", value: "str", config: {}},
        {code: "opt", name: nil, value_type: "select", value: "option1", config: {
          "select_options" => ["option1", "option2", "option3"]
        }}
      )
    end
  end
end
