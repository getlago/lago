# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CustomerPortal::UpdateCustomer do
  subject(:result) do
    execute_graphql(
      customer_portal_user: customer,
      query: mutation,
      variables: {
        input:
      }
    )
  end

  let(:customer) { create(:customer, legal_name: nil) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateCustomerPortalCustomerInput!) {
        updateCustomerPortalCustomer(input: $input) {
          customerType
          name
          firstname
          lastname
          legalName
          taxIdentificationNumber
          email
          addressLine1
          addressLine2
          zipcode
          city
          state
          country
          billingConfiguration {
            documentLocale
          }
          billingEntityBillingConfiguration {
            documentLocale
          }
          shippingAddress {
            addressLine1
            addressLine2
            zipcode
            city
            state
            country
          }
        }
      }
    GQL
  end

  let(:input) do
    {
      customerType: "company",
      name: "Updated customer name",
      firstname: "Updated customer firstname",
      lastname: "Updated customer lastname",
      legalName: "Updated customer legalName",
      taxIdentificationNumber: "2246",
      email: "customer@email.test",
      documentLocale: "fr",
      addressLine1: "Updated customer addressLine1",
      addressLine2: "Updated customer addressLine2",
      zipcode: "Updated customer zipcode",
      city: "Updated customer city",
      state: "Updated customer state",
      country: "PT",
      shippingAddress: {
        addressLine1: "Updated customer shipping addressLine1",
        addressLine2: "Updated customer shipping addressLine2",
        zipcode: "Updated customer shipping zipcode",
        city: "Updated customer shipping city",
        state: "Updated customer shipping state",
        country: "ES"
      }
    }
  end

  it_behaves_like "requires a customer portal user"

  it "updates a customer" do
    result_data = result["data"]["updateCustomerPortalCustomer"]

    expect(result_data["customerType"]).to eq(input[:customerType])
    expect(result_data["name"]).to eq(input[:name])
    expect(result_data["firstname"]).to eq(input[:firstname])
    expect(result_data["lastname"]).to eq(input[:lastname])
    expect(result_data["taxIdentificationNumber"]).to eq(input[:taxIdentificationNumber])
    expect(result_data["legalName"]).to eq(input[:legalName])
    expect(result_data["email"]).to eq(input[:email])
    expect(result_data["addressLine1"]).to eq(input[:addressLine1])
    expect(result_data["addressLine2"]).to eq(input[:addressLine2])
    expect(result_data["zipcode"]).to eq(input[:zipcode])
    expect(result_data["city"]).to eq(input[:city])
    expect(result_data["state"]).to eq(input[:state])
    expect(result_data["country"]).to eq(input[:country])
    expect(result_data["billingConfiguration"]["documentLocale"]).to eq(input[:documentLocale])
    expect(result_data["billingEntityBillingConfiguration"]["documentLocale"]).to eq(customer.billing_entity.document_locale)
    expect(result_data["shippingAddress"]["addressLine1"]).to eq(input[:shippingAddress][:addressLine1])
    expect(result_data["shippingAddress"]["addressLine2"]).to eq(input[:shippingAddress][:addressLine2])
    expect(result_data["shippingAddress"]["zipcode"]).to eq(input[:shippingAddress][:zipcode])
    expect(result_data["shippingAddress"]["city"]).to eq(input[:shippingAddress][:city])
    expect(result_data["shippingAddress"]["state"]).to eq(input[:shippingAddress][:state])
    expect(result_data["shippingAddress"]["country"]).to eq(input[:shippingAddress][:country])
  end

  context "when updating some fields" do
    let(:input) { {name: "Updated customer name"} }

    it "does not change the fields not changed" do
      old_firstname = customer.firstname

      result_data = result["data"]["updateCustomerPortalCustomer"]

      expect(result_data["name"]).to eq(input[:name])
      expect(result_data["firstname"]).to eq(old_firstname)
    end
  end

  context "when updating not allowed fields" do
    let(:input) { {currency: "USD"} }

    it "does not change the fields not changed" do
      expect { result }.not_to change { customer.reload.currency }
    end
  end
end
