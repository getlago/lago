# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::Create do
  let(:required_permission) { "invoices:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:currency) { "EUR" }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:add_on_first) { create(:add_on, organization:) }
  let(:add_on_second) { create(:add_on, amount_cents: 400, organization:) }
  let(:current_time) { DateTime.new(2023, 7, 19, 12, 12) }
  let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
  let(:fees) do
    [
      {
        addOnId: add_on_first.id,
        unitAmountCents: 1200,
        units: 2,
        description: "desc-123",
        invoiceDisplayName: "fee-123",
        taxCodes: [tax.code],
        fromDatetime: current_time.utc.iso8601(3),
        toDatetime: current_time.utc.iso8601(3)
      },
      {
        addOnId: add_on_second.id,
        fromDatetime: current_time.utc.iso8601(3),
        toDatetime: current_time.utc.iso8601(3)
      }
    ]
  end
  let(:mutation) do
    <<-GQL
      mutation($input: CreateInvoiceInput!) {
        createInvoice(input: $input) {
          id,
          feesAmountCents,
          taxesAmountCents,
          totalAmountCents,
          currency,
          taxesRate,
          invoiceType,
          issuingDate,
          purchaseOrderNumber,
          appliedTaxes { id taxCode taxRate },
          fees {
            units
            preciseUnitAmount
            properties {
              fromDatetime
              toDatetime
            }
          },
        }
      }
    GQL
  end

  before { tax }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:create"

  it "creates one-off invoice" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          customerId: customer.id,
          currency:,
          fees:,
          invoiceCustomSection: {invoiceCustomSectionIds: [section_1.id]}
        }
      }
    )

    result_data = result["data"]["createInvoice"]

    expect(result_data).to include(
      "id" => String,
      "issuingDate" => Time.current.to_date.to_s,
      "invoiceType" => "one_off",
      "feesAmountCents" => "2800",
      "taxesAmountCents" => "560",
      "totalAmountCents" => "3360",
      "taxesRate" => 20,
      "currency" => "EUR"
    )
    expect(result_data["appliedTaxes"].map { |t| t["taxCode"] }).to contain_exactly(tax.code)
    expect(result_data["fees"]).to contain_exactly(
      {
        "units" => 2.0,
        "preciseUnitAmount" => 12.0,
        "properties" => {
          "fromDatetime" => current_time.to_time.iso8601,
          "toDatetime" => current_time.to_time.iso8601
        }
      },
      {
        "units" => 1.0,
        "preciseUnitAmount" => 4.0,
        "properties" => {
          "fromDatetime" => current_time.to_time.iso8601,
          "toDatetime" => current_time.to_time.iso8601
        }
      }
    )
    expect(Invoice.one_off.order(created_at: :desc).first.applied_invoice_custom_sections.pluck(:code)).to eq([section_1.code])
  end

  it "creates a one-off invoice with a purchase order number" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          customerId: customer.id,
          currency:,
          fees:,
          purchaseOrderNumber: "PO-123"
        }
      }
    )

    expect(result["data"]["createInvoice"]["purchaseOrderNumber"]).to eq("PO-123")
  end

  context "when multi_entity_billing feature flag is enabled" do
    let(:other_billing_entity) { create(:billing_entity, organization:) }
    let(:mutation) do
      <<-GQL
        mutation($input: CreateInvoiceInput!) {
          createInvoice(input: $input) {
            id
            billingEntity { id code }
          }
        }
      GQL
    end

    before do
      organization.enable_feature_flag!(:multi_entity_billing)
      create(:tax, :applied_to_billing_entity, billing_entity: other_billing_entity, organization:, rate: 20)
    end

    it "stamps the invoice with the resolved billing entity" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            currency:,
            fees:,
            billingEntityId: other_billing_entity.id
          }
        }
      )

      expect(result["data"]["createInvoice"]["billingEntity"]).to include(
        "id" => other_billing_entity.id,
        "code" => other_billing_entity.code
      )
    end

    it "returns a not found error when billing entity is unknown" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            currency:,
            fees:,
            billingEntityId: SecureRandom.uuid
          }
        }
      )

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]).to include("billingEntity" => ["not_found"])
    end
  end

  context "when multi_entity_billing feature flag is disabled" do
    let(:other_billing_entity) { create(:billing_entity, organization:) }
    let(:mutation) do
      <<-GQL
        mutation($input: CreateInvoiceInput!) {
          createInvoice(input: $input) {
            id
            billingEntity { id code }
          }
        }
      GQL
    end

    it "ignores billingEntityId and falls back to the customer's billing entity" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            currency:,
            fees:,
            billingEntityId: other_billing_entity.id
          }
        }
      )

      expect(result["data"]["createInvoice"]["billingEntity"]["id"]).to eq(customer.billing_entity.id)
    end
  end
end
