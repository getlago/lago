# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillingEntities::RemoveTaxes do
  let(:required_permission) { "billing_entities:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:tax_codes) { ["TAX_CODE_1", "TAX_CODE_2"] }

  let(:mutation) do
    <<~GQL
      mutation($input: RemoveTaxesInput!) {
        billingEntityRemoveTaxes(input: $input) {
          removedTaxes {
            id
            code
          }
        }
      }
    GQL
  end

  before do
    allow(BillingEntities::Taxes::RemoveTaxesService).to receive(:call).and_call_original
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:update"

  context "when tax codes exist in the organization" do
    let(:tax1) { create(:tax, organization:, code: "TAX_CODE_1") }
    let(:tax2) { create(:tax, organization:, code: "TAX_CODE_2") }

    before do
      tax1
      tax2
    end

    it "removes the specified taxes from the billing entity" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: [required_permission],
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            taxCodes: tax_codes
          }
        }
      )

      result_data = result["data"]["billingEntityRemoveTaxes"]
      expect(result_data["removedTaxes"].length).to eq(2)
      expect(result_data["removedTaxes"].map { |at| at["code"] }).to match_array(tax_codes)

      expect(BillingEntities::Taxes::RemoveTaxesService).to have_received(:call).with(
        billing_entity: billing_entity,
        tax_codes: tax_codes
      )
    end
  end

  context "when some tax codes do not exist in the organization" do
    let(:tax1) { create(:tax, organization:, code: "TAX_CODE_1") }

    before { tax1 }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: [required_permission],
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            taxCodes: tax_codes
          }
        }
      )

      expect(result["errors"].first["message"]).to include("Resource not found")
    end
  end

  context "when tax_codes is empty" do
    let(:tax_codes) { [] }

    it "returns the billing entity with no applied taxes" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: [required_permission],
        query: mutation,
        variables: {
          input: {
            billingEntityId: billing_entity.id,
            taxCodes: tax_codes
          }
        }
      )

      result_data = result["data"]["billingEntityRemoveTaxes"]
      expect(result_data["removedTaxes"]).to be_empty
    end
  end
end
