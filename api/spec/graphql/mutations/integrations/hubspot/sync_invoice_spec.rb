# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Hubspot::SyncInvoice do
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
  let(:integration_customer) { create(:hubspot_customer, customer:, integration:) }
  let(:integration) { create(:hubspot_integration, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: SyncHubspotIntegrationInvoiceInput!) {
        syncHubspotIntegrationInvoice(input: $input) { invoiceId }
      }
    GQL
  end

  let(:service) { instance_double(Integrations::Aggregator::Invoices::Hubspot::CreateService) }

  let(:result) do
    r = BaseService::Result.new
    r.invoice_id = invoice.id
    r
  end

  before do
    integration_customer
    allow(Integrations::Aggregator::Invoices::Hubspot::CreateService).to receive(:new).and_return(service)
    allow(service).to receive(:call_async).and_return(result)
    execute_graphql_call
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "syncs an invoice" do
    expect(::Integrations::Aggregator::Invoices::Hubspot::CreateService).to have_received(:new).with(invoice:)
    expect(service).to have_received(:call_async)
  end
end
