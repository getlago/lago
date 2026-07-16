# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreatePayInAdvanceChargeJob do
  describe "#perform" do
    let(:charge) { create(:standard_charge, :pay_in_advance, invoiceable: true) }
    let(:event) { create(:event) }
    let(:timestamp) { Time.current.to_i }

    let(:invoice) { nil }
    let(:result) { BaseService::Result.new }

    before do
      allow(Invoices::CreatePayInAdvanceChargeService).to receive(:call)
        .with(charge:, event:, timestamp:)
        .and_return(result)
    end

    it "calls the create pay in advance charge service" do
      described_class.perform_now(charge:, event:, timestamp:)

      expect(Invoices::CreatePayInAdvanceChargeService).to have_received(:call)
    end

    context "when result is a failure" do
      let(:result) do
        BaseService::Result.new.single_validation_failure!(error_code: "error")
      end

      it "raises an error" do
        expect do
          described_class.perform_now(charge:, event:, timestamp:)
        end.to raise_error(BaseService::FailedResult)

        expect(Invoices::CreatePayInAdvanceChargeService).to have_received(:call)
      end

      context "with a previously created invoice" do
        let(:invoice) { create(:invoice, :generating) }

        it "raises an error" do
          expect do
            described_class.perform_now(charge:, event:, timestamp:, invoice:)
          end.to raise_error(BaseService::FailedResult)

          expect(Invoices::CreatePayInAdvanceChargeService).to have_received(:call)
        end
      end

      context "when no invoice is attached to the result" do
        let(:result_invoice) { create(:invoice, :draft) }

        before { result.invoice = nil }

        it "raises an error" do
          expect do
            described_class.perform_now(charge:, event:, timestamp:)
          end.to raise_error(BaseService::FailedResult)

          expect(Invoices::CreatePayInAdvanceChargeService).to have_received(:call)
        end
      end
    end

    describe "retry_on" do
      [
        [Sequenced::SequenceError.new("Sequenced::SequenceError"), 15],
        [Customers::FailedToAcquireLock.new("customer-1-prepaid_credit"), 25],
        [ActiveRecord::StaleObjectError.new("Attempted to update a stale object: Wallet."), 25],
        [BaseService::ThrottlingError.new(provider_name: "Stripe"), 25]
      ].each do |error, attempts|
        error_class = error.class

        context "when a #{error_class} error is raised" do
          before do
            allow(Invoices::CreatePayInAdvanceChargeService).to receive(:call).and_raise(error)
          end

          it "raises a #{error_class.name} error and retries" do
            assert_performed_jobs(attempts, only: [described_class]) do
              expect do
                described_class.perform_later(charge:, event:, timestamp:)
              end.to raise_error(error_class)
            end
          end
        end
      end
    end
  end
end
