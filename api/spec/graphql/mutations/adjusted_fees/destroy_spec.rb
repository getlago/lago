# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AdjustedFees::Destroy do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invoice) { create(:invoice, status: :draft, organization:) }
  let(:fee) { create(:charge_fee, invoice:) }
  let(:adjusted_fee) { create(:adjusted_fee, invoice:, fee:) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyAdjustedFeeInput!) {
        destroyAdjustedFee(input: $input) { id }
      }
    GQL
  end

  before { adjusted_fee }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "destroys an adjusted fee" do
    expect do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: fee.id}}
      )
    end.to change(AdjustedFee, :count).by(-1)
  end
end
