# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Entitlement::FeaturesResolver, :premium do
  subject { execute_query(query:) }

  let(:organization) { create(:organization) }
  let(:required_permission) { "features:view" }
  let(:query) do
    <<~GQL
      query {
        features(limit: 5) {
          collection {
            id
            code
            name
            description
            privileges {
              id
              code
              name
              valueType
              config { selectOptions }
            }
            createdAt
          }
          metadata { currentPage totalCount }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "features:view"

  it do
    expect(described_class).to accept_argument(:limit).of_type("Int")
    expect(described_class).to accept_argument(:page).of_type("Int")
    expect(described_class).to accept_argument(:search_term).of_type("String")
  end

  it "returns a list of features" do
    feature_with_privilege = create(:feature, organization:)
    privilege = create(:privilege, feature: feature_with_privilege, value_type: "boolean")

    feature_without_privilege = create(:feature, organization:)

    result = subject

    expect(result["data"]["features"]["collection"].count).to eq(organization.features.count)

    # Check feature with privilege
    feature_with_privilege_data = result["data"]["features"]["collection"].find { |f| f["code"] == feature_with_privilege.code }
    expect(feature_with_privilege_data["code"]).to eq(feature_with_privilege.code)
    expect(feature_with_privilege_data["name"]).to eq(feature_with_privilege.name)
    expect(feature_with_privilege_data["description"]).to eq(feature_with_privilege.description)
    expect(feature_with_privilege_data["privileges"].count).to eq(1)
    expect(feature_with_privilege_data["privileges"].first["code"]).to eq(privilege.code)
    expect(feature_with_privilege_data["privileges"].first["valueType"]).to eq(privilege.value_type)

    # Check feature without privilege
    feature_without_privilege_data = result["data"]["features"]["collection"].find { |f| f["code"] == feature_without_privilege.code }
    expect(feature_without_privilege_data["code"]).to eq(feature_without_privilege.code)
    expect(feature_without_privilege_data["privileges"].count).to eq(0)

    expect(result["data"]["features"]["metadata"]["currentPage"]).to eq(1)
    expect(result["data"]["features"]["metadata"]["totalCount"]).to eq(2)
  end

  it "does not trigger N+1 queries for privileges", :bullet do
    features = create_list(:feature, 3, organization:)
    features.each do |feature|
      create(:privilege, feature:)
    end

    subject
  end

  context "when search_term is provided" do
    let(:query) do
      <<~GQL
        query {
          features(limit: 5, searchTerm: "testtest") {
            collection {
              id
              code
              name
              description
              privileges {
                id
                code
                name
                valueType
                config { selectOptions }
              }
              createdAt
            }
            metadata { currentPage totalCount }
          }
        }
      GQL
    end

    it "returns features matching the search term" do
      create(:feature, organization:)
      feature1 = create(:feature, organization:, code: "testtest1", name: "Test Feature 1")

      result = subject

      expect(result["data"]["features"]["collection"].sole["code"]).to eq(feature1.code)
    end
  end
end
