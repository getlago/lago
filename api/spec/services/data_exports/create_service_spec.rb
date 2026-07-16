# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExports::CreateService do
  subject(:result) do
    described_class.call(organization:, user:, format:, resource_type:, resource_query:)
  end

  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:membership) { create(:membership, user:, organization:) }

  let(:format) { "csv" }
  let(:resource_type) { "invoices" }
  let(:resource_query) do
    {
      "search_term" => "service 1",
      "filters" => {
        "currency" => "USD"
      }
    }
  end

  before do
    membership
    allow(DataExports::ExportResourcesJob).to receive(:perform_later)
  end

  it "creates a new data export record" do
    expect(result).to be_success

    data_export = result.data_export
    expect(data_export.id).to be_present
    expect(data_export.organization_id).to eq(organization.id)
    expect(data_export.membership_id).to eq(membership.id)
    expect(data_export.format).to eq("csv")
    expect(data_export.resource_type).to eq("invoices")
    expect(data_export.resource_query).to match(resource_query)
    expect(data_export.status).to eq("pending")
  end

  it "calls ExportResourcesJob" do
    data_export = result.data_export

    expect(DataExports::ExportResourcesJob)
      .to have_received(:perform_later)
      .with(data_export)
  end

  it_behaves_like "produces a security log", "export.created" do
    before { result }
  end
end
