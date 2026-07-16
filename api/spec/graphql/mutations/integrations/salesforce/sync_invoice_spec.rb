# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Salesforce::SyncInvoice do
  subject(:execute_graphql_call) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {invoiceId: invoice.id}
      }
    )
  end

  let(:required_permission) { "organization:integrations:update" }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<-GQL
      mutation($input: SyncSalesforceInvoiceInput!) {
        syncSalesforceInvoice(input: $input) { invoiceId }
      }
    GQL
  end

  before do
    allow(SendWebhookJob).to receive(:perform_later)
    execute_graphql_call
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "sends resync invoice webhook" do
    expect(SendWebhookJob).to have_received(:perform_later).with("invoice.resynced", invoice)
  end
end
