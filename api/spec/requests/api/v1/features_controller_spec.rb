# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::FeaturesController do
  let(:organization) { create(:organization) }
  let(:feature1) { create(:feature, organization:, code: "seats", name: "Number of seats", description: "Number of users of the account") }
  let(:feature2) { create(:feature, organization:, code: "storage", name: "Storage", description: "Storage space") }
  let(:privilege1) { create(:privilege, feature: feature1, code: "max_admins", name: "", value_type: "integer") }
  let(:privilege2) { create(:privilege, feature: feature1, code: "max", name: "Maximum", value_type: "integer") }

  before do
    feature1
    feature2
    privilege1
    privilege2
  end

  def indexed_privileges
    json[:feature][:privileges].index_by { it[:code].to_sym }
  end

  describe "POST /api/v1/features" do
    subject { post_with_token(organization, "/api/v1/features", params) }

    let(:params) do
      {
        feature: {
          code: "new_feature",
          name: "New Feature",
          description: "A new feature",
          privileges: [
            {code: "priv1", value_type: "string"},
            {code: "priv2", name: "Maximum", value_type: "integer"},
            {code: "priv3", value_type: "boolean"},
            {code: "priv4", name: "SELECT", value_type: "select", config: {select_options: %w[a b c]}}
          ]
        }
      }
    end

    it "creates a new feature with privileges" do
      expect { subject }.to change(organization.features, :count).by(1)
        .and change(organization.privileges, :count).by(4)

      expect(response).to have_http_status(:success)
      expect(json[:feature][:code]).to eq("new_feature")
      expect(json[:feature][:name]).to eq("New Feature")
      expect(json[:feature][:description]).to eq("A new feature")
      expect(json[:feature][:privileges]).to contain_exactly(
        {code: "priv1", name: nil, value_type: "string", config: {}},
        {code: "priv2", name: "Maximum", value_type: "integer", config: {}},
        {code: "priv3", name: nil, value_type: "boolean", config: {}},
        {code: "priv4", name: "SELECT", value_type: "select", config: {select_options: %w[a b c]}}
      )
    end

    context "when feature code already exists" do
      let(:params) do
        {
          feature: {
            code: "seats", # Already exists
            name: "New Feature",
            description: "A new feature"
          }
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to include("validation_errors")
      end
    end

    context "when feature code is missing" do
      let(:params) do
        {
          feature: {
            name: "New Feature",
            description: "A new feature"
          }
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to include("validation_errors")
      end
    end

    context "when feature code is empty string" do
      let(:params) do
        {
          feature: {
            code: "",
            name: "New Feature",
            description: "A new feature"
          }
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to include("validation_errors")
      end
    end

    context "when privilege value_type is invalid" do
      let(:params) do
        {
          feature: {
            code: "new_feature",
            privileges: [
              {code: "max_admins", value_type: "invalid_type"}
            ]
          }
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details][:"privilege.value_type"]).to eq ["value_is_invalid"]
      end
    end

    context "when privilege code is empty string" do
      let(:params) do
        {
          feature: {
            code: "test",
            name: "New Feature",
            description: "A new feature",
            privileges: [{
              code: " "
            }]
          }
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to include("validation_errors")
      end
    end

    context "when feature has no privileges" do
      let(:params) do
        {
          feature: {
            code: "new_feature",
            name: "New Feature",
            description: "A new feature"
          }
        }
      end

      it "creates a feature without privileges" do
        expect { subject }.to change(Entitlement::Feature, :count).by(1).and(not_change(Entitlement::Privilege, :count))

        expect(response).to have_http_status(:success)
        expect(json[:feature][:code]).to eq("new_feature")
        expect(json[:feature][:privileges]).to eq([])
      end
    end

    context "when feature name and description are optional" do
      let(:params) do
        {
          feature: {
            code: "new_feature",
            privileges: [
              {code: "max_admins", value_type: "integer"}
            ]
          }
        }
      end

      it "creates a feature with only required attributes" do
        expect { subject }.to change(Entitlement::Feature, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json[:feature][:code]).to eq("new_feature")
        expect(json[:feature][:name]).to be_nil
        expect(json[:feature][:description]).to be_nil
      end
    end
  end

  describe "GET /api/v1/features" do
    subject { get_with_token(organization, "/api/v1/features", params) }

    let(:params) { {} }

    it "returns a paginated list of features" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:features].length).to eq(2)

      feature_response = json[:features].find { |f| f[:code] == "seats" }
      expect(feature_response).to include(
        code: "seats",
        name: "Number of seats",
        description: "Number of users of the account"
      )

      expect(feature_response[:privileges]).to contain_exactly(
        {code: "max_admins", name: "", value_type: "integer", config: {}},
        {code: "max", name: "Maximum", value_type: "integer", config: {}}
      )
    end

    it "includes pagination metadata" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:meta]).to include(:current_page, :total_pages, :total_count)
    end

    it "only returns features for the current organization" do
      other_organization = create(:organization)
      create(:feature, organization: other_organization, code: "other_feature")

      subject

      expect(response).to have_http_status(:ok)
      feature_codes = json[:features].map { |f| f[:code] }
      expect(feature_codes).not_to include("other_feature")
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      it "returns features with correct meta data" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:features].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end

    context "with search_term" do
      let(:params) { {search_term: "sto"} }

      it "returns features matching the search term" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:features].count).to eq(1)
        expect(json[:features].first[:code]).to eq("storage")
      end
    end
  end

  describe "GET /api/v1/features/:code" do
    subject { get_with_token(organization, "/api/v1/features/#{feature_code}") }

    let(:feature_code) { feature1.code }

    it "returns a feature" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:feature][:code]).to eq("seats")
      expect(json[:feature][:name]).to eq("Number of seats")
      expect(json[:feature][:description]).to eq("Number of users of the account")
      expect(json[:feature][:privileges]).to contain_exactly(
        {code: "max_admins", name: "", value_type: "integer", config: {}},
        {code: "max", name: "Maximum", value_type: "integer", config: {}}
      )
    end

    context "when feature does not exist" do
      let(:feature_code) { "non_existent" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end

    context "when feature is deleted" do
      before { feature1.discard! }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end
  end

  describe "PATCH /api/v1/features/:code" do
    subject { patch_with_token(organization, "/api/v1/features/#{feature_code}", params) }

    let(:feature_code) { feature1.code }
    let(:params) do
      {
        feature: {
          name: "Updated Feature Name",
          description: "Updated feature description",
          privileges: [
            {code: "max", name: "Max."}
          ]
        }
      }
    end

    it "updates the feature and privilege attributes" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:feature][:name]).to eq("Updated Feature Name")
      expect(json[:feature][:description]).to eq("Updated feature description")
      expect(indexed_privileges[:max][:name]).to eq("Max.")
      expect(indexed_privileges[:max_admins][:name]).to eq("") # unchanged
    end

    it "only updates provided attributes" do
      original_name = feature1.name
      params[:feature].delete(:name)

      subject

      expect(response).to have_http_status(:ok)
      expect(json[:feature][:name]).to eq(original_name)
      expect(json[:feature][:description]).to eq("Updated feature description")
    end

    it "creates privilege non existent privilege" do
      params[:feature][:privileges] << {code: "nonexistent", name: "New Name"}

      subject

      expect(response).to have_http_status(:ok)
      expect(indexed_privileges[:max][:name]).to eq("Max.")
      expect(indexed_privileges[:nonexistent][:name]).to eq("New Name")
    end

    context "when updating only feature attributes" do
      let(:params) do
        {
          feature: {
            name: "Updated Feature Name",
            description: "Updated feature description"
          }
        }
      end

      it "updates only feature attributes" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:feature][:name]).to eq("Updated Feature Name")
        expect(json[:feature][:description]).to eq("Updated feature description")
        expect(indexed_privileges[:max][:name]).to eq("Maximum") # unchanged
      end
    end

    context "when updating only privilege names" do
      let(:params) do
        {
          feature: {
            privileges: [
              {code: "max", name: "Max."},
              {code: "max_admins", name: "Max Admins"}
            ]
          }
        }
      end

      it "updates only privilege names" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:feature][:name]).to eq("Number of seats") # unchanged
        expect(json[:feature][:description]).to eq("Number of users of the account") # unchanged
        expect(indexed_privileges[:max][:name]).to eq("Max.")
        expect(indexed_privileges[:max_admins][:name]).to eq("Max Admins")
      end
    end

    context "when feature does not exist" do
      let(:feature_code) { "non_existent" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end

    context "when feature belongs to another organization" do
      let(:other_organization) { create(:organization) }
      let(:other_feature) { create(:feature, organization: other_organization, code: "other_feature") }
      let(:feature_code) { other_feature.code }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end

    context "when privilege name is empty" do
      let(:params) do
        {
          feature: {
            privileges: [
              {code: "max", name: ""} # Empty name is allowed
            ]
          }
        }
      end

      it "updates the privilege name to empty string" do
        subject

        expect(response).to have_http_status(:ok)
        expect(indexed_privileges[:max][:name]).to eq("")
      end
    end

    context "when feature name is empty" do
      let(:params) do
        {
          feature: {
            name: "" # Empty name is allowed
          }
        }
      end

      it "updates the feature name to empty string" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:feature][:name]).to eq("")
      end
    end
  end

  describe "DELETE /api/v1/features/:code" do
    subject { delete_with_token(organization, "/api/v1/features/#{feature_code}") }

    let(:feature_code) { feature1.code }

    it "discards the feature" do
      expect { subject }.to change { feature1.reload.discarded? }.from(false).to(true)
    end

    it "discards all privileges associated with the feature" do
      expect { subject }.to change { Entitlement::Privilege.kept.count }.by(-2)
    end

    it "returns the discarded feature" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:feature][:code]).to eq("seats")
      expect(json[:feature][:name]).to eq("Number of seats")
      expect(json[:feature][:description]).to eq("Number of users of the account")
    end

    context "when feature does not exist" do
      let(:feature_code) { "non_existent" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end

    context "when feature belongs to another organization" do
      let(:other_organization) { create(:organization) }
      let(:other_feature) { create(:feature, organization: other_organization, code: "other_feature") }
      let(:feature_code) { other_feature.code }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end

    context "when feature is already discarded" do
      before { feature1.discard! }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("feature")
      end
    end
  end
end
