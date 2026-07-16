# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::SyncCreditNote do
  subject(:execute_graphql_call) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {creditNoteId: credit_note.id}
      }
    )
  end

  let(:required_permission) { "organization:integrations:update" }
  let(:credit_note) { create(:credit_note, customer:, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:integration_customer) { create(:netsuite_customer, customer:, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: SyncIntegrationCreditNoteInput!) {
        syncIntegrationCreditNote(input: $input) { creditNoteId }
      }
    GQL
  end

  let(:service) { instance_double(Integrations::Aggregator::CreditNotes::CreateService) }

  let(:result) do
    r = BaseService::Result.new
    r.credit_note_id = credit_note.id
    r
  end

  before do
    integration_customer
    allow(Integrations::Aggregator::CreditNotes::CreateService).to receive(:new).and_return(service)
    allow(service).to receive(:call_async).and_return(result)
    execute_graphql_call
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "syncs a credit note" do
    expect(::Integrations::Aggregator::CreditNotes::CreateService).to have_received(:new).with(credit_note:)
    expect(service).to have_received(:call_async)
  end
end
