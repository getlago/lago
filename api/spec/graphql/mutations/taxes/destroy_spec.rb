# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Taxes::Destroy do
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyTaxInput!) {
        destroyTax(input: $input) { id }
      }
    GQL
  end

  before { tax }

  it "destroys a tax" do
    expect do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        query: mutation,
        variables: {input: {id: tax.id}}
      )
    end.to change(Tax, :count).by(-1)
  end
end
