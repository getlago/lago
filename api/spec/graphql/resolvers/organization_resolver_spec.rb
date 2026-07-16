# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::OrganizationResolver do
  let(:query) do
    <<~GQL
      query {
        organization {
          id
          name
          email
          city
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  it "returns the current organization" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {}
    )

    data = result["data"]["organization"]

    expect(data["id"]).to eq(organization.id)
    expect(data["name"]).to eq(organization.name)
    expect(data["email"]).to eq(organization.email)
    expect(data["city"]).to eq(organization.city)
  end

  context "with field requiring permissions" do
    let(:query) do
      <<~GQL
        query {
          organization {
            taxIdentificationNumber
            apiKey
            webhookUrl
            billingConfiguration { invoiceFooter }
            emailSettings
            taxes { id code }
          }
        }
      GQL
    end

    it "returns the current organization" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: Permission.permissions_hash(:admin),
        query:,
        variables: {}
      )

      data = result["data"]["organization"]

      expect(data["taxIdentificationNumber"]).to eq(organization.tax_identification_number)
      expect(data["apiKey"]).to eq(organization.api_keys.first.value)
      expect(data["webhookUrl"]).to eq(organization.webhook_endpoints.first.webhook_url)
      expect(data["billingConfiguration"]["invoiceFooter"]).to eq(organization.invoice_footer)
      expect(data["emailSettings"]).to eq(organization.email_settings.map { it.tr(".", "_") })
      expect(data["taxes"]).to eq []
    end
  end
end
