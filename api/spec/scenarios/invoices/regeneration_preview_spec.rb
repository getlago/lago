# frozen_string_literal: true

require "rails_helper"

describe "Invoice regeneration preview" do
  include GraphQLHelper

  let(:query) do
    <<~GQL
      query($id: ID!) {
        invoiceBuildRegenerationPreview(id: $id) {
          id
          taxesRate
          appliedTaxes {
            taxCode
            taxRate
            amountCents
          }
          fees {
            id
            taxesRate
            appliedTaxes {
              taxCode
              taxRate
              amountCents
            }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership, organization:) }
  let(:organization) do
    create(
      :organization,
      country: "FR",
      webhook_url: nil,
      eu_tax_management: false,
      billing_entities: [create(:billing_entity, country: "FR")]
    )
  end
  let(:customer) { Customer.find_by!(external_id: "customer_fr") }
  let(:add_on) { create(:add_on, organization:, amount_cents: 10_000) }

  it "rebuilds applied taxes using the current customer taxes" do
    Organizations::UpdateService.call!(organization:, params: {eu_tax_management: true})

    mock_vies_check!("FR12345678901")
    create_or_update_customer(
      {
        external_id: "customer_fr",
        name: "Jean",
        country: "FR",
        zipcode: "75018",
        currency: "EUR",
        tax_identification_number: "FR12345678901"
      }
    )

    expect(customer.reload.pending_vies_check).to be_nil
    expect(customer.taxes.sole.code).to eq("lago_eu_fr_standard")
    expect(customer.taxes.sole.rate).to eq(20.0)

    create_one_off_invoice(customer, [add_on])

    invoice = customer.invoices.sole
    fee = invoice.fees.sole
    expect(invoice.applied_taxes.sole.tax_code).to eq("lago_eu_fr_standard")
    expect(invoice.taxes_rate).to eq(20.0)
    expect(fee.applied_taxes.sole.tax_code).to eq("lago_eu_fr_standard")
    expect(fee.taxes_rate).to eq(20.0)

    create_or_update_customer({external_id: customer.external_id, tax_identification_number: nil})

    mock_vies_check!("ES12345678Z")
    create_or_update_customer(
      {
        external_id: customer.external_id,
        country: "ES",
        zipcode: "28001",
        tax_identification_number: "ES12345678Z"
      }
    )

    expect(customer.reload.taxes.sole.code).to eq("lago_eu_reverse_charge")
    expect(customer.taxes.sole.rate).to eq(0.0)

    data = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: "invoices:view",
      query:,
      variables: {id: invoice.id}
    )["data"]["invoiceBuildRegenerationPreview"]
    preview_fee = data["fees"].sole

    expect(data["id"]).to eq(invoice.id)
    expect(data["appliedTaxes"].map { |tax| tax["taxCode"] }).to eq(["lago_eu_reverse_charge"])
    expect(data["taxesRate"]).to eq(0.0)
    expect(preview_fee["id"]).to eq(fee.id)
    expect(preview_fee["appliedTaxes"].map { |tax| tax["taxCode"] }).to eq(["lago_eu_reverse_charge"])
    expect(preview_fee["taxesRate"]).to eq(0.0)

    expect(invoice.reload.applied_taxes.sole.tax_code).to eq("lago_eu_fr_standard")
    expect(invoice.taxes_rate).to eq(20.0)
    expect(fee.reload.applied_taxes.sole.tax_code).to eq("lago_eu_fr_standard")
    expect(fee.taxes_rate).to eq(20.0)
  end
end
