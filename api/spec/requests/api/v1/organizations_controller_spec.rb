# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::OrganizationsController do
  let(:organization) { create(:organization) }
  let(:webhook_url) { Faker::Internet.url }

  describe "PUT /api/v1/organizations" do
    subject do
      put_with_token(
        organization,
        "/api/v1/organizations",
        {organization: update_params}
      )
    end

    let(:update_params) do
      {
        country: "pl",
        default_currency: "EUR",
        address_line1: "address1",
        address_line2: "address2",
        state: "state",
        zipcode: "10000",
        email: "mail@example.com",
        city: "test_city",
        legal_name: "test1",
        legal_number: "123",
        timezone: "Europe/Paris",
        webhook_url:,
        email_settings: ["invoice.finalized"],
        document_number_prefix: "ORG-2",
        finalize_zero_amount_invoice: false,
        billing_configuration: {
          invoice_footer: "footer",
          invoice_grace_period: 3,
          document_locale: "fr"
        }
      }
    end

    include_examples "requires API permission", "organization", "write"

    it "updates an organization" do
      put_with_token(
        organization,
        "/api/v1/organizations",
        {organization: update_params}
      )

      expect(response).to have_http_status(:success)

      expect(json[:organization][:name]).to eq(organization.name)
      expect(json[:organization][:default_currency]).to eq("EUR")
      expect(json[:organization][:webhook_url]).to eq(webhook_url)
      expect(json[:organization][:webhook_urls]).to eq([webhook_url])
      expect(json[:organization][:document_numbering]).to eq("per_customer")
      expect(json[:organization][:document_number_prefix]).to eq("ORG-2")
      expect(json[:organization][:finalize_zero_amount_invoice]).to eq(false)
      # TODO(:timezone): Timezone update is turned off for now
      # expect(json[:organization][:timezone]).to eq(update_params[:timezone])

      billing = json[:organization][:billing_configuration]
      expect(billing[:invoice_footer]).to eq("footer")
      expect(billing[:document_locale]).to eq("fr")

      expect(json[:organization][:taxes]).not_to be_nil
    end

    context "with premium features", :premium do
      it "updates an organization" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:organization][:timezone]).to eq(update_params[:timezone])
        expect(json[:organization][:email_settings]).to eq(update_params[:email_settings])

        billing = json[:organization][:billing_configuration]
        expect(billing[:invoice_grace_period]).to eq(3)
      end
    end
  end

  describe "GET /api/v1/organizations/grpc_token" do
    subject { get_with_token(organization, "/api/v1/organizations/grpc_token") }

    include_examples "requires API permission", "organization", "read"

    it "returns the grpc_token" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:organization][:grpc_token]).not_to be_nil
    end
  end

  describe "GET /api/v1/organizations" do
    subject { get_with_token(organization, "/api/v1/organizations") }

    include_examples "requires API permission", "organization", "read"

    it "returns the organization" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:organization][:name]).to eq(organization.name)
    end
  end
end
