# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::FillFromInvoiceJob do
  subject(:compute_job) { described_class }

  let(:subscription) { create(:subscription) }
  let(:invoice) { create(:invoice, :subscription, subscriptions: [subscription]) }

  let(:result) { BaseService::Result.new }

  describe ".perform" do
    it "delegates its logic to the DailyUsages::FillFromInvoiceService" do
      allow(DailyUsages::FillFromInvoiceService).to receive(:call)
        .with(invoice:, subscriptions: [subscription])
        .and_return(result)

      compute_job.perform_now(invoice:, subscriptions: [subscription])

      expect(DailyUsages::FillFromInvoiceService).to have_received(:call)
        .with(invoice:, subscriptions: [subscription]).once
    end
  end
end
