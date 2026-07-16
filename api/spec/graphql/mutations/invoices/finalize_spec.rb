# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::Finalize do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, :draft, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: FinalizeInvoiceInput!) {
        finalizeInvoice(input: $input) {
          id
          status
          taxStatus
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "finalizes the given invoice" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: invoice.id}
      }
    )

    result_data = result["data"]["finalizeInvoice"]

    expect(result_data["id"]).to be_present
    expect(result_data["status"]).to eq("finalized")
  end

  context "with tax provider" do
    let(:integration) { create(:anrok_integration, organization:) }
    let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
    let(:timestamp) { Time.zone.now.beginning_of_month }
    let(:subscription) do
      create(
        :subscription,
        customer:,
        subscription_at: Time.current - 3.months,
        started_at: Time.current - 3.months,
        created_at: Time.current - 3.months
      )
    end
    let(:date_service) do
      Subscriptions::DatesService.new_instance(
        subscription,
        Time.zone.at(timestamp),
        current_usage: false
      )
    end
    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        subscription:,
        invoice:,
        timestamp:,
        from_datetime: date_service.from_datetime,
        to_datetime: date_service.to_datetime,
        charges_from_datetime: date_service.charges_from_datetime,
        charges_to_datetime: date_service.charges_to_datetime
      )
    end

    before do
      integration_customer
      invoice_subscription
    end

    it "returns pending invoice" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      result_data = result["data"]["finalizeInvoice"]

      expect(result_data["id"]).to be_present
      expect(result_data["status"]).to eq("pending")
      expect(result_data["taxStatus"]).to eq("pending")
    end
  end
end
