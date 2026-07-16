# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Entitlement::UpdateFeature, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "features:update" }
  let(:organization) { create(:organization) }
  let(:feature) do
    create(:feature, organization:)
  end

  let(:query) do
    <<-GQL
      mutation($input: UpdateFeatureInput!) {
        updateFeature(input: $input) {
          id
          name
          description
          code
          privileges { code name }
        }
      }
    GQL
  end
  let(:input) do
    {
      id: feature.id,
      name: "Updated Feature Name",
      description: "Updated Feature Description",
      privileges: []
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "features:update"

  it "updates a feature" do
    result = subject

    result_data = result["data"]["updateFeature"]

    expect(result_data["name"]).to eq("Updated Feature Name")
    expect(result_data["description"]).to eq("Updated Feature Description")
    expect(result_data["code"]).to eq(feature.code)
    expect(result_data["privileges"]).to be_empty
  end

  context "when feature does not exist" do
    let(:input) do
      {
        id: "non-existent-id",
        name: "Updated Feature Name",
        description: "Updated Feature Description",
        privileges: []
      }
    end

    it "returns not found error for non-existent feature" do
      expect_graphql_error(
        result: subject,
        message: "not_found"
      )
    end
  end

  context "with privileges" do
    context "when privilege already exists" do
      let(:input) do
        {
          id: feature.id,
          name: "Feature Name",
          description: "Feature Description",
          privileges: [
            {code: "seats", name: "new name"}
          ]
        }
      end

      it "updates the privilege" do
        create(:privilege, feature:, code: "seats", name: "Old Name")

        result = subject

        result_data = result["data"]["updateFeature"]

        expect(result_data["privileges"].size).to eq(1)
        expect(result_data["privileges"].sole["code"]).to eq("seats")
        expect(result_data["privileges"].sole["name"]).to eq("new name")
      end
    end

    context "when privilege is new" do
      let(:new_privilege_code) { "new_privilege" }
      let(:new_privilege_name) { "New Privilege" }
      let(:input) do
        {
          id: feature.id,
          name: "Updated Feature Name",
          description: "Updated Feature Description",
          privileges: [
            {code: new_privilege_code, name: new_privilege_name}
          ]
        }
      end

      it "adds new privileges to the feature" do
        result = subject

        result_data = result["data"]["updateFeature"]

        expect(result_data["privileges"].size).to eq(1)
        expect(result_data["privileges"].sole["code"]).to eq(new_privilege_code)
        expect(result_data["privileges"].sole["name"]).to eq(new_privilege_name)
      end
    end
  end
end
