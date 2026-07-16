# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AddOns::Update do
  let(:required_permission) { "addons:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, organization:) }
  let(:tax2) { create(:tax, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:mutation) do
    <<-GQL
      mutation($input: UpdateAddOnInput!) {
        updateAddOn(input: $input) {
          id,
          name,
          invoiceDisplayName,
          code,
          description,
          amountCents,
          amountCurrency,
          taxes { id code rate }
        }
      }
    GQL
  end

  before { create(:add_on_applied_tax, add_on:, tax:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "addons:update"

  it "updates an add-on" do
    result = execute_query(
      query: mutation,
      input: {
        id: add_on.id,
        name: "New name",
        invoiceDisplayName: "New invoice name",
        code: "new_code",
        description: "desc",
        amountCents: 123,
        amountCurrency: "USD",
        taxCodes: [tax2.code]
      }
    )

    result_data = result["data"]["updateAddOn"]

    expect(result_data["name"]).to eq("New name")
    expect(result_data["invoiceDisplayName"]).to eq("New invoice name")
    expect(result_data["code"]).to eq("new_code")
    expect(result_data["description"]).to eq("desc")
    expect(result_data["amountCents"]).to eq("123")
    expect(result_data["amountCurrency"]).to eq("USD")
    expect(result_data["taxes"].map { |t| t["code"] }).to contain_exactly(tax2.code)
  end
end
