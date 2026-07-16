# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::RetryAllJob do
  subject(:retry_all_job) { described_class }

  let(:retry_batch_service) { instance_double(Invoices::RetryBatchService) }
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, organization:) }

  before do
    allow(Invoices::RetryBatchService).to receive(:new)
      .and_return(retry_batch_service)
    allow(retry_batch_service).to receive(:call)
      .and_return(result)
  end

  it "calls the retry batch service" do
    retry_all_job.perform_now(organization:, invoice_ids: [invoice.id])

    expect(Invoices::RetryBatchService).to have_received(:new)
    expect(retry_batch_service).to have_received(:call)
  end
end
