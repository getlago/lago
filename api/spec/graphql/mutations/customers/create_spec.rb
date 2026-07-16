# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Customers::Create do
  let(:required_permissions) { "customers:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:tax) { create(:tax, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: CreateCustomerInput!) {
        createCustomer(input: $input) {
          id
          name
          firstname
          lastname
          displayName
          customerType
          externalId
          city
          country
          paymentProvider
          providerCustomer { id, providerCustomerId providerPaymentMethods }
          currency
          taxIdentificationNumber
          timezone
          netPaymentTerm
          canEditAttributes
          invoiceGracePeriod
          finalizeZeroAmountInvoice
          billingConfiguration { 
            subscriptionInvoiceIssuingDateAnchor
            subscriptionInvoiceIssuingDateAdjustment
            documentLocale 
          }
          shippingAddress { addressLine1 city state }
          metadata { id, key, value, displayInInvoice }
          taxes { code }
          billingEntity { code }
        }
      }
    GQL
  end

  let(:body) do
    {
      object: "event",
      data: {url: "test.url"}
    }
  end

  before do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(status: 200, body: body.to_json, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "customers:create"

  it "creates a customer" do
    stripe_provider

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permissions,
      query: mutation,
      variables: {
        input: {
          name: "John Doe Inc",
          firstname: "John",
          lastname: "Doe",
          customerType: "company",
          externalId: "john_doe_2",
          city: "London",
          country: "GB",
          paymentProvider: "stripe",
          taxIdentificationNumber: "123456789",
          currency: "EUR",
          netPaymentTerm: 30,
          finalizeZeroAmountInvoice: "skip",
          billingEntityCode: billing_entity.code,
          providerCustomer: {
            providerCustomerId: "cu_12345",
            providerPaymentMethods: ["card"]
          },
          billingConfiguration: {
            documentLocale: "fr",
            subscriptionInvoiceIssuingDateAnchor: "current_period_end",
            subscriptionInvoiceIssuingDateAdjustment: "keep_anchor"
          },
          shippingAddress: {
            addressLine1: "Test 12",
            zipcode: "102030",
            state: "test state",
            city: "Paris"
          },
          metadata: [
            {
              key: "manager",
              value: "John Doe",
              displayInInvoice: true
            }
          ],
          taxCodes: [tax.code]
        }
      }
    )

    result_data = result["data"]["createCustomer"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("John Doe Inc")
    expect(result_data["firstname"]).to eq("John")
    expect(result_data["lastname"]).to eq("Doe")
    expect(result_data["displayName"]).to eq("John Doe Inc - John Doe")
    expect(result_data["customerType"]).to eq("company")
    expect(result_data["externalId"]).to eq("john_doe_2")
    expect(result_data["city"]).to eq("London")
    expect(result_data["country"]).to eq("GB")
    expect(result_data["currency"]).to eq("EUR")
    expect(result_data["taxIdentificationNumber"]).to eq("123456789")
    expect(result_data["paymentProvider"]).to eq("stripe")
    expect(result_data["providerCustomer"]["id"]).to be_present
    expect(result_data["providerCustomer"]["providerCustomerId"]).to eq("cu_12345")
    expect(result_data["providerCustomer"]["providerPaymentMethods"]).to eq(["card"])
    expect(result_data["invoiceGracePeriod"]).to be_nil
    expect(result_data["billingConfiguration"]["documentLocale"]).to eq("fr")
    expect(result_data["billingConfiguration"]["subscriptionInvoiceIssuingDateAnchor"]).to eq("current_period_end")
    expect(result_data["billingConfiguration"]["subscriptionInvoiceIssuingDateAdjustment"]).to eq("keep_anchor")
    expect(result_data["shippingAddress"]["addressLine1"]).to eq("Test 12")
    expect(result_data["shippingAddress"]["city"]).to eq("Paris")
    expect(result_data["shippingAddress"]["state"]).to eq("test state")
    expect(result_data["netPaymentTerm"]).to eq(30)
    expect(result_data["finalizeZeroAmountInvoice"]).to eq("skip")
    expect(result_data["metadata"].count).to eq(1)
    expect(result_data["metadata"][0]["value"]).to eq("John Doe")
    expect(result_data["taxes"][0]["code"]).to eq(tax.code)
    expect(result_data["billingEntity"]["code"]).to eq(billing_entity.code)
  end

  context "with premium feature", :premium do
    it "creates a customer" do
      stripe_provider

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permissions,
        query: mutation,
        variables: {
          input: {
            name: "John Doe",
            externalId: "john_doe_2",
            city: "London",
            country: "GB",
            paymentProvider: "stripe",
            currency: "EUR",
            timezone: "TZ_EUROPE_PARIS",
            providerCustomer: {
              providerCustomerId: "cu_12345",
              providerPaymentMethods: ["card"]
            },
            invoiceGracePeriod: 2
          }
        }
      )

      result_data = result["data"]["createCustomer"]

      expect(result_data["timezone"]).to eq("TZ_EUROPE_PARIS")
      expect(result_data["invoiceGracePeriod"]).to eq(2)
    end
  end

  context "with validation errors" do
    it "returns an error with validation messages" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permissions,
        query: mutation,
        variables: {
          input: {
            name: "John Doe",
            externalId: "john_doe_2",
            city: "London",
            country: 0
          }
        }
      )

      expect(result["errors"]).to be_present
    end
  end
end
