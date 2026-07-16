# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Taxes::Create do
  let(:membership) { create(:membership) }
  let(:input) do
    {
      name: "Tax name",
      code: "tax-code",
      description: "Tax description",
      rate: 15.0
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: TaxCreateInput!) {
        createTax(input: $input) {
          id name code description rate addOnsCount plansCount chargesCount customersCount
        }
      }
    GQL
  end

  it "creates a tax" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      query: mutation,
      variables: {input:}
    )

    expect(result["data"]["createTax"]).to include(
      "id" => String,
      "name" => "Tax name",
      "code" => "tax-code",
      "description" => "Tax description",
      "rate" => 15.0
    )
  end
end
