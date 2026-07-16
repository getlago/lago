# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreatePayInAdvanceFixedChargesJob do
  subject(:perform_now) { described_class.perform_now(subscription, timestamp) }

  let(:subscription) { create(:subscription) }
  let(:timestamp) { Time.current.to_i }
  let(:result) { BaseService::Result.new }

  describe "#perform" do
    before do
      allow(Invoices::CreatePayInAdvanceFixedChargesService).to receive(:call)
        .with(subscription:, timestamp:).and_return(result)
    end

    it "calls the create pay in advance fixed charges service" do
      perform_now

      expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
    end

    context "when result is a failure" do
      let(:result) do
        BaseService::Result.new.single_validation_failure!(error_code: "error")
      end

      it "raises an error" do
        expect do
          perform_now
        end.to raise_error(BaseService::FailedResult)

        expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
      end
    end

    context "when result is a tax error" do
      let(:result) do
        BaseService::Result.new.validation_failure!(errors: {tax_error: ["taxDateTooFarInFuture"]})
      end

      it "does not raise an error" do
        expect { perform_now }.not_to raise_error

        expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
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
            allow(Invoices::CreatePayInAdvanceFixedChargesService).to receive(:call).and_raise(error)
          end

          it "raises a #{error_class.name} error and retries" do
            assert_performed_jobs(attempts, only: [described_class]) do
              expect do
                described_class.perform_later(subscription, timestamp)
              end.to raise_error(error_class)
            end
          end
        end
      end
    end
  end
end
