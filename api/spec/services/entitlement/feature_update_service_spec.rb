# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::FeatureUpdateService do
  subject { described_class.call(feature:, params:, partial:) }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege1) { create(:privilege, feature:, code: "max", name: "Maximum") }
  let(:privilege2) { create(:privilege, feature:, code: "min", name: "Minimum") }
  let(:privilege3) { create(:privilege, feature:, code: "opt", name: "Optional") }
  let(:params) { {} }
  let(:partial) { false }

  before do
    privilege1
    privilege2
    privilege3
  end

  describe "#call", :premium do
    context "when update is full" do
      let(:partial) { false }

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

      context "when updating feature attributes" do
        let(:params) do
          {
            name: "Updated Feature Name",
            description: "Updated feature description"
          }
        end

        it "updates the feature name and description" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("Updated Feature Name")
          expect(result.feature.description).to eq("Updated feature description")
        end

        it "sends feature.updated webhook" do
          expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("feature.updated", feature)
        end

        it "produces an activity log" do
          result = subject
          expect(Utils::ActivityLog).to have_produced("feature.updated").after_commit.with(result.feature)
        end

        it "only updates provided attributes" do
          original_name = feature.name
          params.delete(:name)

          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq(original_name)
          expect(result.feature.description).to eq("Updated feature description")
        end
      end

      context "when updating privileges" do
        let(:params) do
          {
            privileges: [
              {code: "max", name: "Max."},
              {code: "min", name: "Min."}
            ]
          }
        end

        it "updates the privilege names and delete missing privileges" do
          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq("Max.")
          expect(privilege2.reload.name).to eq("Min.")
          expect(privilege3.reload.deleted_at).to be_present
          expect(feature.privileges.pluck(:code)).to match_array(%w[max min])
        end

        it "only updates provided privilege attributes" do
          original_name = privilege1.name
          params[:privileges] = [
            {code: "max"},
            {code: "min", name: "Min."}
          ]

          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq(original_name)
          expect(privilege2.reload.name).to eq("Min.")
        end
      end

      context "when updating both feature and privileges" do
        let(:params) do
          {
            name: "Updated Feature Name",
            description: "Updated feature description",
            privileges: [
              {code: "max", name: "Max."}
            ]
          }
        end

        it "updates both feature and privilege attributes" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("Updated Feature Name")
          expect(result.feature.description).to eq("Updated feature description")
          expect(privilege1.reload.name).to eq("Max.")
          expect(feature.privileges.reload.count).to eq(1)
          expect(feature.privileges.pluck(:code)).to eq(%w[max])
        end
      end

      context "when updating select_options of a privilege" do
        let(:privilege3) { create(:privilege, feature:, code: "opt", value_type: "select", config: {select_options: %w[zero one]}) }

        let(:params) do
          {
            privileges: [
              {code: "opt", config: {select_options: %w[one two three]}}
            ]
          }
        end

        it "appends the new options" do
          result = subject

          expect(result).to be_success
          expect(privilege3.reload.config["select_options"]).to eq %w[zero one two three]
        end
      end

      context "when deleting privileges with associated entitlement values" do
        let(:entitlement) { create(:entitlement, feature:) }
        let(:privilege1_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: "10") }
        let(:privilege2_value) { create(:entitlement_value, entitlement:, privilege: privilege2, value: "true") }
        let(:privilege3_value) { create(:entitlement_value, entitlement:, privilege: privilege3, value: "option1") }

        let(:params) do
          {
            privileges: [
              {code: "max", name: "Max."}
            ]
          }
        end

        before do
          privilege1_value
          privilege2_value
          privilege3_value
        end

        it "soft deletes entitlement values for removed privileges" do
          result = subject

          expect(result).to be_success
          expect(Entitlement::EntitlementValue.with_discarded.count).to eq(3)
          expect(Entitlement::EntitlementValue.count).to eq(1) # only privilege1_value remains
          expect(privilege1_value.reload).to be_present
          expect(privilege2_value.reload).to be_discarded
          expect(privilege3_value.reload).to be_discarded
        end

        it "soft deletes the removed privileges" do
          result = subject

          expect(result).to be_success
          expect(Entitlement::Privilege.with_discarded.count).to eq(3)
          expect(Entitlement::Privilege.count).to eq(1) # only privilege1 remains
          expect(privilege1.reload).to be_present
          expect(privilege2.reload).to be_discarded
          expect(privilege3.reload).to be_discarded
        end
      end

      context "when new privileges is provided" do
        let(:new_privilege_code) { "     new_privilege     " }
        let(:params) do
          {
            privileges: [
              {code: new_privilege_code, name: "New Privilege"}
            ]
          }
        end

        it "creates a new privilege" do
          result = subject

          expect(result).to be_success
          expect(feature.privileges.reload.count).to eq(1)
          expect(feature.privileges.sole.code).to eq("new_privilege")
          expect(feature.privileges.sole.name).to eq("New Privilege")
          expect(feature.privileges.sole.value_type).to eq("string")
        end

        context "when new privilege params are invalid" do
          let(:params) do
            {
              privileges: [
                {code: new_privilege_code, name: "New Privilege", value_type: "invalid_type"}
              ]
            }
          end

          it "returns a validation failure" do
            result = subject

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to include("privilege.value_type": ["value_is_invalid"])
          end
        end
      end

      context "when feature is nil" do
        let(:params) { {name: "Updated Name"} }

        it "returns a not found failure" do
          result = described_class.call(feature: nil, params:, partial:)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("feature")
        end
      end

      context "when privilege name is empty" do
        let(:params) do
          {
            privileges: [
              {code: "max", name: ""} # Empty name is allowed
            ]
          }
        end

        it "updates the privilege name to empty string" do
          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq("")
        end
      end

      context "when feature name is empty" do
        let(:params) { {name: ""} }

        it "updates the feature name to empty string" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("")
        end
      end

      context "when feature is attached to a plan" do
        let(:params) { {} }
        let(:entitlement) { create(:entitlement, feature:) }
        let(:privilege1_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 10) }
        let(:privilege2_value) { create(:entitlement_value, entitlement:, privilege: privilege2, value: true) }

        before do
          privilege1_value
          privilege2_value
        end

        it "sends plan.updated webhook" do
          expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", entitlement.plan)
        end

        it "produces plan.updated logs" do
          subject
          expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(entitlement.plan)
        end
      end

      shared_examples "discards all privileges" do
        it "discards all existing privileges" do
          result = subject

          expect(result).to be_success
          expect(feature.privileges.reload.count).to eq(0)
        end
      end

      context "when no privileges are provided" do
        let(:params) { {name: "Updated Name"} }

        it_behaves_like "discards all privileges"
      end

      context "when privileges parameter is empty hash" do
        let(:params) { {name: "Updated Name", privileges: {}} }

        it_behaves_like "discards all privileges"
      end

      context "when privileges parameter is nil" do
        let(:params) { {name: "Updated Name", privileges: nil} }

        it_behaves_like "discards all privileges"
      end
    end

    describe "when update is partial" do
      let(:partial) { true }

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

      context "when updating feature attributes" do
        let(:params) do
          {
            name: "Updated Feature Name",
            description: "Updated feature description"
          }
        end

        it "updates the feature name and description" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("Updated Feature Name")
          expect(result.feature.description).to eq("Updated feature description")
        end

        it "sends feature.updated webhook" do
          expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("feature.updated", feature)
        end

        it "produces an activity log" do
          result = subject
          expect(Utils::ActivityLog).to have_produced("feature.updated").after_commit.with(result.feature)
        end

        it "only updates provided attributes" do
          original_name = feature.name
          params.delete(:name)

          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq(original_name)
          expect(result.feature.description).to eq("Updated feature description")
        end
      end

      context "when updating privilege names" do
        let(:params) do
          {
            privileges: [
              {code: "max", name: "Max."},
              {code: "min", name: "Min."}
            ]
          }
        end

        it "updates the privilege names" do
          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq("Max.")
          expect(privilege2.reload.name).to eq("Min.")
        end

        it "only updates privileges that exist" do
          params[:privileges] << {code: "nonexistent", name: "New Name"}

          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq("Max.")
          expect(privilege2.reload.name).to eq("Min.")
        end

        it "only updates provided privilege attributes" do
          original_name = privilege1.name
          params[:privileges] = [
            {code: "max"},
            {code: "min", name: "Min."}
          ]

          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq(original_name)
          expect(privilege2.reload.name).to eq("Min.")
        end
      end

      context "when updating select_options of a privilege" do
        let(:privilege3) { create(:privilege, feature:, code: "opt", value_type: "select", config: {select_options: %w[zero one]}) }

        let(:params) do
          {
            privileges: [
              {code: "opt", config: {select_options: %w[one two three]}}
            ]
          }
        end

        it "appends the new options" do
          result = subject

          expect(result).to be_success
          expect(privilege3.reload.config["select_options"]).to eq %w[zero one two three]
        end
      end

      context "when updating both feature and privileges" do
        let(:params) do
          {
            name: "Updated Feature Name",
            description: "Updated feature description",
            privileges: [
              {code: "max", name: "Max."}
            ]
          }
        end

        it "updates both feature and privilege attributes" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("Updated Feature Name")
          expect(result.feature.description).to eq("Updated feature description")
          expect(privilege1.reload.name).to eq("Max.")
          expect(privilege2.reload.name).to eq("Minimum") # unchanged
        end
      end

      context "when feature is nil" do
        let(:params) { {name: "Updated Name"} }

        it "returns a not found failure" do
          result = described_class.call(feature: nil, params:, partial:)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("feature")
        end
      end

      context "when privilege name is empty" do
        let(:params) do
          {
            privileges: [
              {code: "max", name: ""} # Empty name is allowed
            ]
          }
        end

        it "updates the privilege name to empty string" do
          result = subject

          expect(result).to be_success
          expect(privilege1.reload.name).to eq("")
        end
      end

      context "when feature name is empty" do
        let(:params) { {name: ""} }

        it "updates the feature name to empty string" do
          result = subject

          expect(result).to be_success
          expect(result.feature.name).to eq("")
        end
      end

      context "when new privileges is provided" do
        let(:new_privilege_code) { "new_privilege" }
        let(:params) do
          {
            privileges: [
              {code: new_privilege_code, name: "New Privilege"}
            ]
          }
        end

        it "creates a new privilege" do
          result = subject

          expect(result).to be_success
          expect(feature.privileges.reload.count).to eq(4) # 3 existing + 1 new
          p = feature.privileges.find_by(code: new_privilege_code)
          expect(p.name).to eq("New Privilege")
          expect(p.value_type).to eq("string")
        end

        context "when new privilege params are invalid" do
          let(:params) do
            {
              privileges: [
                {code: new_privilege_code, name: "New Privilege", value_type: "invalid_type"}
              ]
            }
          end

          it "returns a validation failure" do
            result = subject

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to include("privilege.value_type": ["value_is_invalid"])
          end
        end
      end

      context "when feature is attached to a plan" do
        let(:params) { {} }
        let(:entitlement) { create(:entitlement, feature:) }
        let(:privilege1_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 10) }
        let(:privilege2_value) { create(:entitlement_value, entitlement:, privilege: privilege2, value: true) }

        before do
          privilege1_value
          privilege2_value
        end

        it "sends plan.updated webhook" do
          expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("plan.updated", entitlement.plan)
        end

        it "produces plan.updated logs" do
          subject
          allow(Utils::ActivityLog).to receive(:produce_after_commit).and_call_original
        end
      end
    end
  end
end
