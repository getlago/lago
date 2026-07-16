# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::FeatureCreateService do
  subject { described_class.call(organization:, params:) }

  let(:organization) { create(:organization) }
  let(:params) do
    {
      code: "seats",
      name: "Number of seats",
      description: "Number of users of the account",
      privileges: [
        {code: "max_admins", value_type: "integer"},
        {code: "max", name: "Maximum", value_type: "integer"}
      ]
    }
  end

  describe "#call", :premium do
    it "creates a feature with the provided attributes" do
      expect { subject }.to change(Entitlement::Feature, :count).by(1)

      result = subject
      expect(result).to be_success
      expect(result.feature.code).to eq("seats")
      expect(result.feature.name).to eq("Number of seats")
      expect(result.feature.description).to eq("Number of users of the account")
      expect(result.feature.organization).to eq(organization)
    end

    it "trims code" do
      params[:code] = "  seats  "
      params[:privileges] = [{code: "  test "}]
      result = subject
      expect(result.feature.code).to eq "seats"
      expect(result.feature.privileges.sole.code).to eq "test"
    end

    it "produces an activity log" do
      result = subject
      expect(Utils::ActivityLog).to have_produced("feature.created").after_commit.with(result.feature)
    end

    it "sends feature.created webhook" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("feature.created", instance_of(Entitlement::Feature))
    end

    it "creates privileges for the feature" do
      expect { subject }.to change(Entitlement::Privilege, :count).by(2)

      result = subject
      expect(result).to be_success

      privileges = result.feature.privileges
      expect(privileges.count).to eq(2)

      max_admins_privilege = privileges.find_by(code: "max_admins")
      expect(max_admins_privilege.value_type).to eq("integer")
      expect(max_admins_privilege.name).to be_nil

      max_privilege = privileges.find_by(code: "max")
      expect(max_privilege.value_type).to eq("integer")
      expect(max_privilege.name).to eq("Maximum")
    end

    context "when organization is nil" do
      let(:organization) { nil }

      it "returns a not found failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("organization")
      end
    end

    context "when feature code is invalid" do
      let(:params) do
        {
          code: "", # Invalid empty code
          name: "Number of seats",
          description: "Number of users of the account"
        }
      end

      it "returns a validation failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:code]).to eq ["value_is_mandatory"]
      end
    end

    context "when feature code already exists" do
      before do
        create(:feature, organization:, code: "seats")
      end

      it "returns a validation failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:code]).to eq ["value_already_exist"]
      end
    end

    context "when privilege value_type is not set" do
      let(:params) do
        {
          code: "seats",
          name: "Number of seats",
          description: "Number of users of the account",
          privileges: [
            {code: "max_admins"}
          ]
        }
      end

      it "defaults to string" do
        result = subject

        expect(result).to be_success
        expect(result.feature.privileges.sole.value_type).to eq "string"
      end
    end

    context "when privilege code is duplicated" do
      let(:params) do
        {
          code: "seats",
          privileges: [
            {code: "max_admins"},
            {code: "max_admins"}
          ]
        }
      end

      it "returns a validation failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:"privilege.code"]).to eq ["value_is_duplicated"]
      end
    end

    context "when privilege value_type is invalid" do
      let(:params) do
        {
          code: "seats",
          name: "Number of seats",
          description: "Number of users of the account",
          privileges: [
            {code: "max_admins", value_type: "invalid_type"}
          ]
        }
      end

      it "returns a validation failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:"privilege.value_type"]).to eq ["value_is_invalid"]
      end
    end

    context "when privilege code is invalid" do
      let(:params) do
        {
          code: "seats",
          name: "Number of seats",
          description: "Number of users of the account",
          privileges: [
            {value_type: "integer"} # Invalid empty code
          ]
        }
      end

      it "returns a validation failure" do
        result = subject

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:"privilege.code"]).to eq ["value_is_mandatory"]
      end
    end

    context "when feature has no privileges" do
      let(:params) do
        {
          code: "seats",
          name: "Number of seats",
          description: "Number of users of the account"
        }
      end

      it "creates a feature without privileges" do
        expect { subject }.to change(Entitlement::Feature, :count).by(1).and(not_change(Entitlement::Privilege, :count))

        result = subject
        expect(result).to be_success
        expect(result.feature.privileges).to be_empty
      end
    end

    context "when feature name and description, and privilege name are optional" do
      let(:params) do
        {
          code: "seats",
          privileges: [
            {code: "max_admins", value_type: "integer"}
          ]
        }
      end

      it "creates a feature with only required attributes" do
        expect { subject }.to change(Entitlement::Feature, :count).by(1)

        result = subject
        expect(result).to be_success
        expect(result.feature.code).to eq("seats")
        expect(result.feature.name).to be_nil
        expect(result.feature.description).to be_nil
      end
    end

    context "when privilege has config" do
      let(:params) do
        {
          code: "sso",
          privileges: [
            {
              code: "provider",
              name: "Provider Name",
              value_type: "select",
              config: {select_options: %w[okta ad google custom]}
            }
          ]
        }
      end

      it "creates privilege with config" do
        expect { subject }.to change(Entitlement::Privilege, :count).by(1)

        result = subject
        expect(result).to be_success

        privilege = result.feature.privileges.first
        expect(privilege.code).to eq("provider")
        expect(privilege.name).to eq("Provider Name")
        expect(privilege.value_type).to eq("select")
        expect(privilege.config).to eq({"select_options" => %w[okta ad google custom]})
      end
    end
  end
end
