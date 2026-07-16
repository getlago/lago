# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::RefreshWalletJob do
  describe "queue routing" do
    let(:customer) { create(:customer) }

    context "when the customer's organization is in the dedicated list" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [customer.organization_id]) }

      it "routes to the dedicated queue" do
        expect(described_class.new(customer).queue_name).to eq("dedicated_wallets")
      end
    end

    context "when the customer's organization is not in the dedicated list" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", ["some-other-org-id"]) }

      it "falls back to low_priority" do
        expect(described_class.new(customer).queue_name).to eq("low_priority")
      end
    end

    context "when the dedicated list is empty" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", []) }

      it "falls back to low_priority" do
        expect(described_class.new(customer).queue_name).to eq("low_priority")
      end
    end
  end

  describe "#perform" do
    subject { described_class.perform_now(customer, wallet_ids:) }

    let(:customer) { create(:customer, awaiting_wallet_refresh:) }
    let(:organization) { customer.organization }
    let(:result) { BaseService::Result.new }
    let(:wallet_ids) { nil }

    before do
      allow(Customers::RefreshWalletsService).to receive(:call).with(customer:, target_wallet_ids: wallet_ids).and_return(result)
    end

    context "when customer is not awaiting wallet refresh" do
      let(:awaiting_wallet_refresh) { false }

      it "does not call the Customers::RefreshWalletsService service" do
        subject
        expect(Customers::RefreshWalletsService).not_to have_received(:call)
      end

      context "when wallet_ids are provided" do
        let(:wallet_ids) { create_list(:wallet, 2, customer:).map(&:id) }

        it "calls the Customers::RefreshWalletsService service scoped to the given wallets" do
          subject
          expect(Customers::RefreshWalletsService).to have_received(:call).with(customer:, target_wallet_ids: wallet_ids)
        end
      end
    end

    context "when customer is awaiting wallet refresh" do
      let(:awaiting_wallet_refresh) { true }

      context "when refresh customer's wallets succeeds" do
        it "calls the Customers::RefreshWalletsService service" do
          subject
          expect(Customers::RefreshWalletsService).to have_received(:call).with(customer:, target_wallet_ids: nil)
        end
      end

      context "when wallet_ids are provided" do
        let(:wallet_ids) { create_list(:wallet, 2, customer:).map(&:id) }

        it "calls the Customers::RefreshWalletsService service scoped to the given wallets" do
          subject
          expect(Customers::RefreshWalletsService).to have_received(:call).with(customer:, target_wallet_ids: wallet_ids)
        end
      end

      context "when a tax_error error_detail already exists" do
        before do
          create(:error_detail, owner: customer, organization:, error_code: :tax_error)
        end

        it "does not call the Customers::RefreshWalletsService service" do
          subject
          expect(Customers::RefreshWalletsService).not_to have_received(:call)
        end
      end

      context "when refresh customer's wallets fails with a tax error" do
        let(:result) { BaseService::Result.new.validation_failure!(errors: {tax_error: ["customerAddressCouldNotResolve"]}) }

        context "when the error is related to the customer's address" do
          it "creates a tax_error error_detail on the customer" do
            expect { subject }.to change { customer.error_details.tax_error.count }.by(1)
          end

          it "does not re-raise the error" do
            expect { subject }.not_to raise_error
          end
        end

        [
          Integrations::Aggregator::OutOfMemoryError,
          Integrations::Aggregator::TaskInProgressError,
          Integrations::Aggregator::TaskExpiredError,
          Integrations::Aggregator::OrchestratorFailureError,
          Integrations::Aggregator::ServerContentionError,
          Integrations::Aggregator::TimeoutError
        ].each do |error_class|
          context "when the error is #{error_class.name.demodulize.underscore.humanize.downcase}" do
            before do
              allow(Customers::RefreshWalletsService).to receive(:call).with(customer:, target_wallet_ids: nil).and_raise(error_class)
            end

            it "raises the error and retries the job" do
              assert_performed_jobs(6, only: [described_class]) do
                expect do
                  described_class.perform_later(customer)
                end.to raise_error(error_class)
              end
            end
          end
        end

        context "when the tax error is an unknown failure" do
          let(:result) { BaseService::Result.new.validation_failure!(errors: {tax_error: ["failure"]}) }

          it "does not create an error_detail and re-raises the error" do
            expect { subject }.to raise_error(BaseService::ValidationFailure).and not_change { customer.error_details.count }
          end
        end
      end

      context "when refresh customer's wallets fails with a non-tax error" do
        let(:result) { BaseService::Result.new.validation_failure!(errors: {other_error: ["something"]}) }

        it "re-raises the error" do
          expect { subject }.to raise_error(BaseService::ValidationFailure)
        end
      end
    end
  end
end
