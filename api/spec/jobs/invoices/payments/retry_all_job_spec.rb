# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::RetryAllJob do
  subject(:retry_all_job) { described_class }

  let(:retry_batch_service) { instance_double(Invoices::Payments::RetryBatchService) }
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, organization:) }

  before do
    allow(Invoices::Payments::RetryBatchService).to receive(:new)
      .and_return(retry_batch_service)
    allow(retry_batch_service).to receive(:call)
      .and_return(result)
  end

  it "calls the retry batch service" do
    retry_all_job.perform_now(organization_id: organization.id, invoice_ids: [invoice.id])

    expect(Invoices::Payments::RetryBatchService).to have_received(:new)
    expect(retry_batch_service).to have_received(:call)
  end
end
