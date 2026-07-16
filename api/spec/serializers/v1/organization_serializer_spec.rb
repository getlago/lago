# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::OrganizationSerializer do
  subject(:serializer) do
    described_class.new(org, root_name: "organization", includes: %i[taxes])
  end

  let(:webhook_urls) { org.webhook_endpoints.map(&:webhook_url) }
  let(:org) { create(:organization) }
  let(:tax) { create(:tax, organization: org, applied_to_organization: true) }

  before { tax }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["organization"]["name"]).to eq(org.name)
    expect(result["organization"]["slug"]).to eq(org.slug)
    expect(result["organization"]["default_currency"]).to eq(org.default_currency)
    expect(result["organization"]["created_at"]).to eq(org.created_at.iso8601)
    expect(result["organization"]["webhook_url"]).to eq(webhook_urls.first)
    expect(result["organization"]["webhook_urls"]).to eq(webhook_urls)
    expect(result["organization"]["country"]).to eq(org.country)
    expect(result["organization"]["address_line1"]).to eq(org.address_line1)
    expect(result["organization"]["address_line2"]).to eq(org.address_line2)
    expect(result["organization"]["state"]).to eq(org.state)
    expect(result["organization"]["zipcode"]).to eq(org.zipcode)
    expect(result["organization"]["email"]).to eq(org.email)
    expect(result["organization"]["city"]).to eq(org.city)
    expect(result["organization"]["legal_name"]).to eq(org.legal_name)
    expect(result["organization"]["legal_number"]).to eq(org.legal_number)
    expect(result["organization"]["billing_configuration"]["invoice_footer"]).to eq(org.invoice_footer)
    expect(result["organization"]["billing_configuration"]["invoice_grace_period"]).to eq(org.invoice_grace_period)
    expect(result["organization"]["billing_configuration"]["document_locale"]).to eq(org.document_locale)
    expect(result["organization"]["tax_identification_number"]).to eq(org.tax_identification_number)
    expect(result["organization"]["timezone"]).to eq(org.timezone)
    expect(result["organization"]["net_payment_term"]).to eq(org.net_payment_term)
    expect(result["organization"]["finalize_zero_amount_invoice"]).to eq(org.finalize_zero_amount_invoice)
    expect(result["organization"]["taxes"].count).to eq(1)
    expect(result["organization"]["events_store"]).to eq(org.events_store)
  end
end
