# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ProviderTaxes::PullTaxesAndApplyJob do
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, customer:) }
  let(:customer) { create(:customer, organization:) }

  let(:result) { BaseService::Result.new }

  before do
    allow(Invoices::ProviderTaxes::PullTaxesAndApplyService).to receive(:call)
      .with(invoice:)
      .and_return(result)
  end

  it "calls successfully the service" do
    described_class.perform_now(invoice:)

    expect(Invoices::ProviderTaxes::PullTaxesAndApplyService).to have_received(:call)
  end

  describe "unique" do
    it "has unique :until_executed constraint" do
      expect(described_class.lock_strategy_class).to eq(ActiveJob::Uniqueness::Strategies::UntilExecuted)
    end
  end

  describe "retry_on" do
    [
      [Customers::FailedToAcquireLock.new("customer-1-prepaid_credit"), 25],
      [ActiveRecord::StaleObjectError.new("Attempted to update a stale object: Wallet."), 25],
      [Sequenced::SequenceError.new("Unable to acquire lock on the database"), 15],
      [BaseService::ThrottlingError.new, 25],
      [LagoHttpClient::HttpError.new(401, "body", "uri"), 6],
      [OpenSSL::SSL::SSLError.new("OpenSSL::SSL::SSLError"), 6],
      [Net::ReadTimeout.new("Net::ReadTimeout"), 6],
      [Net::OpenTimeout.new("Net::OpenTimeout"), 6],
      [Integrations::Aggregator::BadGatewayError.new("body", "uri"), 6],
      [Integrations::Aggregator::RequestLimitError.new(LagoHttpClient::HttpError.new(429, "limit", "uri")), 6],
      [Integrations::Aggregator::OutOfMemoryError.new, 6],
      [Integrations::Aggregator::TaskInProgressError.new, 6],
      [Integrations::Aggregator::TaskExpiredError.new, 6],
      [Integrations::Aggregator::OrchestratorFailureError.new, 6],
      [Integrations::Aggregator::ServerContentionError.new, 6],
      [Integrations::Aggregator::TimeoutError.new, 6]
    ].each do |error, attempts|
      error_class = error.class

      context "when a #{error_class} error is raised" do
        before do
          allow(Invoices::ProviderTaxes::PullTaxesAndApplyService).to receive(:call).and_raise(error)
        end

        it "raises a #{error_class.name} error and retries" do
          assert_performed_jobs(attempts, only: [described_class]) do
            expect do
              described_class.perform_later(invoice:)
            end.to raise_error(error_class)
          end
        end
      end
    end
  end
end
