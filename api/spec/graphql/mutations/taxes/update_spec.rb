# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Taxes::Update do
  let(:membership) { create(:membership) }
  let(:tax) { create(:tax, organization: membership.organization) }
  let(:input) do
    {
      id: tax.id,
      name: "Updated tax name",
      code: "updated-tax-code",
      description: "Updated tax description",
      rate: 30.0,
      appliedToOrganization: false
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: TaxUpdateInput!) {
        updateTax(input: $input) {
          id name code description rate appliedToOrganization
        }
      }
    GQL
  end

  it "updates a tax" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      query: mutation,
      variables: {input:}
    )

    expect(result["data"]["updateTax"]).to include(
      "id" => String,
      "name" => "Updated tax name",
      "code" => "updated-tax-code",
      "description" => "Updated tax description",
      "rate" => 30.0,
      "appliedToOrganization" => false
    )
  end
end
