# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillingEntities::Update, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "billing_entities:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:invoice_custom_sections) { create_list(:invoice_custom_section, 2, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateBillingEntityInput!) {
        updateBillingEntity(input: $input) {
          id
          name
          code
          defaultCurrency
          email
          legalName
          legalNumber
          taxIdentificationNumber
          addressLine1
          addressLine2
          phone
          city
          country
          netPaymentTerm
          state
          zipcode
          timezone
          logoUrl
          euTaxManagement
          documentNumberPrefix
          documentNumbering
          emailSettings
          finalizeZeroAmountInvoice
          billingConfiguration {
            invoiceFooter,
            invoiceGracePeriod,
            documentLocale,
            subscriptionInvoiceIssuingDateAnchor,
            subscriptionInvoiceIssuingDateAdjustment,
          }
          selectedInvoiceCustomSections { id }
        }
      }
    GQL
  end

  let(:logo) do
    logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
    base64_logo = Base64.encode64(logo_file)

    "data:image/png;base64,#{base64_logo}"
  end

  let(:input) do
    {
      id: billing_entity.id,
      code: billing_entity.code,
      name: "Updated entity",
      email: "updated@email.com",
      legalName: "Updated legal name",
      legalNumber: "1234567890",
      taxIdentificationNumber: "Tax-1234",
      addressLine1: "Calle de la Princesa 1",
      addressLine2: "Apt 1",
      phone: "+49 30 1234567",
      city: "Barcelona",
      state: "Barcelona",
      zipcode: "08001",
      country: "ES",
      defaultCurrency: "EUR",
      timezone: "TZ_EUROPE_MADRID",
      documentNumbering: "per_billing_entity",
      documentNumberPrefix: "NEW-0001",
      euTaxManagement: true,
      finalizeZeroAmountInvoice: true,
      netPaymentTerm: 15,
      logo: logo,
      emailSettings: ["invoice_finalized", "credit_note_created"],
      billingConfiguration: {
        invoiceFooter: "invoice footer",
        documentLocale: "es",
        invoiceGracePeriod: 10,
        subscriptionInvoiceIssuingDateAnchor: "current_period_end",
        subscriptionInvoiceIssuingDateAdjustment: "keep_anchor"
      },
      invoiceCustomSectionIds: invoice_custom_sections.map(&:id)
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:update"

  context "with valid input" do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )
    end

    it "updates the billing entity" do
      result_data = result["data"]["updateBillingEntity"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq(billing_entity.code)
      expect(result_data["name"]).to eq("Updated entity")
      expect(result_data["email"]).to eq("updated@email.com")
      expect(result_data["legalName"]).to eq("Updated legal name")
      expect(result_data["legalNumber"]).to eq("1234567890")
      expect(result_data["taxIdentificationNumber"]).to eq("Tax-1234")
      expect(result_data["addressLine1"]).to eq("Calle de la Princesa 1")
      expect(result_data["addressLine2"]).to eq("Apt 1")
      expect(result_data["phone"]).to eq("+49 30 1234567")
      expect(result_data["state"]).to eq("Barcelona")
      expect(result_data["city"]).to eq("Barcelona")
      expect(result_data["zipcode"]).to eq("08001")
      expect(result_data["country"]).to eq("ES")
      expect(result_data["defaultCurrency"]).to eq("EUR")
      expect(result_data["timezone"]).to eq("TZ_EUROPE_MADRID")
      expect(result_data["documentNumbering"]).to eq("per_billing_entity")
      expect(result_data["documentNumberPrefix"]).to eq("NEW-0001")
      expect(result_data["euTaxManagement"]).to eq true
      expect(result_data["finalizeZeroAmountInvoice"]).to eq true
      expect(result_data["netPaymentTerm"]).to eq(15)
      expect(result_data["logoUrl"]).to match(%r{.*/rails/active_storage/blobs/redirect/.*/logo})
      expect(result_data["emailSettings"]).to be_nil
      expect(result_data["billingConfiguration"]).to be_nil
      expect(result_data["selectedInvoiceCustomSections"]).to match_array(invoice_custom_sections.map { |section| {"id" => section.id} })
    end

    it_behaves_like "produces a security log", "billing_entity.updated"
  end

  context "with valid input and extra view permissions" do
    let(:permissions) do
      [required_permission].concat(%w[billing_entities:view])
    end

    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions:,
        query: mutation,
        variables: {input:}
      )
    end

    it "includes the email settings and billing configuration in the response" do
      result_data = result["data"]["updateBillingEntity"]

      expect(result_data["emailSettings"]).to eq(["invoice_finalized", "credit_note_created"])
      expect(result_data["billingConfiguration"]["invoiceFooter"]).to eq("invoice footer")
      expect(result_data["billingConfiguration"]["documentLocale"]).to eq("es")
      expect(result_data["billingConfiguration"]["invoiceGracePeriod"]).to eq(10)
      expect(result_data["billingConfiguration"]["subscriptionInvoiceIssuingDateAnchor"]).to eq("current_period_end")
      expect(result_data["billingConfiguration"]["subscriptionInvoiceIssuingDateAdjustment"]).to eq("keep_anchor")
    end
  end

  context "when the billing entity is not found" do
    it "returns a not found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: "non_existent_id",
            name: "Updated entity"
          }
        }
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
