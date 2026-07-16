# frozen_string_literal: true

RSpec.describe Api::V1::Features::PrivilegesController do
  let(:organization) { create(:organization) }
  let(:feature1) { create(:feature, organization:, code: "seats", name: "Number of seats", description: "Number of users of the account") }
  let(:privilege1) { create(:privilege, feature: feature1, code: "max_admins", name: "", value_type: "integer") }
  let(:privilege2) { create(:privilege, feature: feature1, code: "max", name: "Maximum", value_type: "integer") }

  before do
    feature1
    privilege1
    privilege2
  end

  describe "DELETE /api/v1/features/:feature_code/privileges/:code" do
    subject { delete_with_token(organization, "/api/v1/features/#{feature_code}/privileges/#{privilege_code}") }

    let(:feature_code) { feature1.code }
    let(:privilege_code) { privilege1.code }

    it "discards the privilege" do
      expect { subject }.to change { privilege1.reload.discarded? }.from(false).to(true)
    end

    it "returns the feature without the discarded privilege" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:feature][:code]).to eq("seats")
      expect(json[:feature][:privileges]).not_to include(:max_admins)
      expect(json[:feature][:privileges]).to contain_exactly(
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

    context "when privilege does not exist" do
      let(:privilege_code) { "non_existent" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("privilege")
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

    context "when privilege belongs to another feature" do
      let(:other_feature) { create(:feature, organization:, code: "other_feature") }
      let(:other_privilege) { create(:privilege, feature: other_feature, code: "other_privilege") }
      let(:privilege_code) { other_privilege.code }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("privilege")
      end
    end

    context "when privilege is already discarded" do
      before { privilege1.discard! }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("privilege")
      end
    end
  end
end
