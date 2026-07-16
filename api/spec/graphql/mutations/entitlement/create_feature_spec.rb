# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Entitlement::CreateFeature, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "features:create" }

  let(:organization) { create(:organization) }
  let(:query) do
    <<-GQL
      mutation($input: CreateFeatureInput!) {
        createFeature(input: $input) {
          id
          code
          name
          description
          privileges {
            code
            name
            valueType
          }
        }
      }
    GQL
  end

  let(:input) do
    {
      code: "test_feature",
      name: "Test Feature",
      description: "Test Feature Description",
      privileges: []
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "features:create"

  it "creates a feature" do
    result = subject

    result_data = result["data"]["createFeature"]

    expect(result_data["code"]).to eq("test_feature")
    expect(result_data["name"]).to eq("Test Feature")
    expect(result_data["description"]).to eq("Test Feature Description")
    expect(result_data["privileges"]).to be_empty
  end

  context "when creating feature with privileges" do
    let(:privilege_code) { "test_privilege" }
    let(:privilege_name) { "Test Privilege" }
    let(:input) do
      {
        code: "test_feature_with_privileges",
        name: "Test Feature With Privileges",
        description: "Test Feature Description",
        privileges: [
          {code: privilege_code, name: privilege_name}
        ]
      }
    end

    it "creates a feature with privileges" do
      result = subject

      result_data = result["data"]["createFeature"]

      expect(result_data["code"]).to eq("test_feature_with_privileges")
      expect(result_data["name"]).to eq("Test Feature With Privileges")
      expect(result_data["description"]).to eq("Test Feature Description")
      expect(result_data["privileges"].size).to eq(1)
      expect(result_data["privileges"].sole["code"]).to eq(privilege_code)
      expect(result_data["privileges"].sole["name"]).to eq(privilege_name)
      expect(result_data["privileges"].sole["valueType"]).to eq("string")
    end
  end
end
