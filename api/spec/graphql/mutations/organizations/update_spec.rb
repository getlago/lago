# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Organizations::Update do
  let(:membership) { create(:membership) }
  let(:mutation) do
    <<~GQL
      mutation($input: UpdateOrganizationInput!) {
        updateOrganization(input: $input) {
          legalNumber
          legalName
          taxIdentificationNumber
          email
          addressLine1
          addressLine2
          state
          zipcode
          city
          country
          defaultCurrency
          netPaymentTerm
          timezone
          emailSettings
          webhookUrl
          euTaxManagement,
          documentNumbering
          documentNumberPrefix
          finalizeZeroAmountInvoice
          billingConfiguration {
            invoiceFooter,
            invoiceGracePeriod,
            documentLocale,
          }
          authenticationMethods
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"

  it "updates an organization" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: Permission.permissions_hash(:admin),
      query: mutation,
      variables: {
        input: {
          legalNumber: "1234",
          legalName: "Foobar",
          taxIdentificationNumber: "2246",
          email: "foo@bar.com",
          addressLine1: "Line 1",
          addressLine2: "Line 2",
          netPaymentTerm: 10,
          state: "Foobar",
          zipcode: "FOO1234",
          city: "Foobar",
          country: "FR",
          defaultCurrency: "EUR",
          euTaxManagement: true,
          webhookUrl: "https://app.test.dev",
          documentNumberPrefix: "ORG-2",
          finalizeZeroAmountInvoice: false,
          billingConfiguration: {
            invoiceFooter: "invoice footer",
            documentLocale: "fr"
          }
        }
      }
    )

    result_data = result["data"]["updateOrganization"]

    expect(result_data["legalNumber"]).to eq("1234")
    expect(result_data["legalName"]).to eq("Foobar")
    expect(result_data["taxIdentificationNumber"]).to eq("2246")
    expect(result_data["email"]).to eq("foo@bar.com")
    expect(result_data["addressLine1"]).to eq("Line 1")
    expect(result_data["addressLine2"]).to eq("Line 2")
    expect(result_data["state"]).to eq("Foobar")
    expect(result_data["zipcode"]).to eq("FOO1234")
    expect(result_data["city"]).to eq("Foobar")
    expect(result_data["country"]).to eq("FR")
    expect(result_data["defaultCurrency"]).to eq("EUR")
    expect(result_data["netPaymentTerm"]).to eq(10)
    expect(result_data["webhookUrl"]).to eq("https://app.test.dev")
    expect(result_data["documentNumbering"]).to eq("per_customer")
    expect(result_data["documentNumberPrefix"]).to eq("ORG-2")
    expect(result_data["billingConfiguration"]["invoiceFooter"]).to eq("invoice footer")
    expect(result_data["billingConfiguration"]["invoiceGracePeriod"]).to eq(0)
    expect(result_data["billingConfiguration"]["documentLocale"]).to eq("fr")
    expect(result_data["euTaxManagement"]).to be_truthy
    expect(result_data["timezone"]).to eq("TZ_UTC")
    expect(result_data["finalizeZeroAmountInvoice"]).to be false
  end

  context "without necessary permissions" do
    it "ignores permissions-protected field and updates the rest" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: %w[],
        query: mutation,
        variables: {
          input: {
            email: "foo@bar2.com",
            taxIdentificationNumber: "tax007",
            emailSettings: ["invoice_finalized"]
          }
        }
      )

      result_data = result["data"]["updateOrganization"]

      expect(result_data["email"]).to eq "foo@bar2.com"
      expect(result_data["taxIdentificationNumber"]).to eq "tax007"
      expect(result_data["emailSettings"]).to be_nil
    end
  end

  context "with premium features", :premium do
    let(:timezone) { "TZ_EUROPE_PARIS" }

    it "updates an organization" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: %w[organization:emails:view organization:invoices:view],
        query: mutation,
        variables: {
          input: {
            email: "foo@bar.com",
            timezone:,
            billingConfiguration: {
              invoiceGracePeriod: 3
            },
            emailSettings: ["invoice_finalized"],
            authenticationMethods: ["google_oauth"]
          }
        }
      )

      result_data = result["data"]["updateOrganization"]

      expect(result_data["timezone"]).to eq(timezone)
      expect(result_data["billingConfiguration"]["invoiceGracePeriod"]).to eq(3)
      expect(result_data["emailSettings"]).to eq(["invoice_finalized"])
      expect(result_data["authenticationMethods"]).to eq(["google_oauth"])
    end

    context "with Etc/GMT+12 timezone" do
      let(:timezone) { "TZ_ETC_GMT_12" }

      it "updates an organization" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: membership.organization,
          permissions: "organization:invoices:view",
          query: mutation,
          variables: {
            input: {
              email: "foo@bar.com",
              timezone:,
              billingConfiguration: {
                invoiceGracePeriod: 3
              }
            }
          }
        )

        result_data = result["data"]["updateOrganization"]

        expect(result_data["timezone"]).to eq(timezone)
        expect(result_data["billingConfiguration"]["invoiceGracePeriod"]).to eq(3)
      end
    end
  end
end
