# frozen_string_literal: true

require "rails_helper"

describe Clock::RefreshWalletsOngoingBalanceJob, job: true do
  describe "#perform" do
    subject { described_class.perform_now }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:, awaiting_wallet_refresh: true) }
    let(:wallet) { create(:wallet, customer:) }
    let(:customer_without_wallet) { create(:customer, organization:, awaiting_wallet_refresh: true) }

    let(:customer_with_terminated_wallet) do
      create(:customer, organization:, awaiting_wallet_refresh: true) do |customer|
        create(:wallet, customer:, status: :terminated)
      end
    end

    before do
      wallet
      customer_without_wallet
      customer_with_terminated_wallet
      allow(Customers::RefreshWalletsService).to receive(:call)
    end

    context "when freemium" do
      it "does not schedule refresh job" do
        subject
        expect(Customers::RefreshWalletJob).not_to have_been_enqueued
      end
    end

    context "when premium", :premium do
      it "schedules refresh job for customers with active wallet awaiting refresh" do
        subject
        expect(Customers::RefreshWalletJob).to have_been_enqueued.with(customer)
      end

      it "does not schedule refresh job for customers with terminated wallet or not awaiting for refresh" do
        subject
        expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer_without_wallet)
        expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer_with_terminated_wallet)
      end

      context "when customer has tax errors" do
        before { create(:error_detail, owner: customer, error_code: ErrorDetail.error_codes[:tax_error]) }

        it "does not schedule refresh job for customers with tax errors" do
          subject
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer)
        end
      end

      context "when the customer's organization is handled by the dedicated worker" do
        before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [organization.id]) }

        it "does not schedule refresh job for customers in the dedicated organization" do
          subject
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer)
        end

        context "with a customer in a non-dedicated organization" do
          let(:other_organization) { create(:organization) }
          let(:other_customer) { create(:customer, organization: other_organization, awaiting_wallet_refresh: true) }

          before { create(:wallet, customer: other_customer) }

          it "still schedules refresh job for customers outside the dedicated list" do
            subject
            expect(Customers::RefreshWalletJob).to have_been_enqueued.with(other_customer)
          end
        end
      end
    end
  end
end
