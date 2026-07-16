# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::RefreshDedicatedOrgWalletsOngoingBalanceJob, job: true do
  describe "#perform" do
    subject { described_class.perform_now }

    let(:target_organization) { create(:organization) }
    let(:other_organization) { create(:organization) }
    let(:target_customer) { create(:customer, organization: target_organization, awaiting_wallet_refresh: true) }
    let(:other_customer) { create(:customer, organization: other_organization, awaiting_wallet_refresh: true) }
    let(:customer_without_wallet) do
      create(:customer, organization: target_organization, awaiting_wallet_refresh: true)
    end
    let(:customer_with_terminated_wallet) do
      create(:customer, organization: target_organization, awaiting_wallet_refresh: true) do |customer|
        create(:wallet, customer:, status: :terminated)
      end
    end

    before do
      create(:wallet, customer: target_customer)
      create(:wallet, customer: other_customer)
      customer_without_wallet
      customer_with_terminated_wallet
    end

    context "when the dedicated org list is empty" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", []) }

      context "when premium", :premium do
        it "does not enqueue any refresh job" do
          subject
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued
        end
      end
    end

    context "when the dedicated org list contains the target organization" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [target_organization.id]) }

      context "when freemium" do
        it "does not enqueue refresh jobs" do
          subject
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued
        end
      end

      context "when premium", :premium do
        it "enqueues refresh jobs for flagged customers with active wallets in target org only" do
          subject
          expect(Customers::RefreshWalletJob).to have_been_enqueued.with(target_customer)
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(other_customer)
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer_without_wallet)
          expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(customer_with_terminated_wallet)
        end

        context "when the target customer has tax errors" do
          before do
            create(:error_detail, owner: target_customer, error_code: ErrorDetail.error_codes[:tax_error])
          end

          it "does not enqueue the refresh job for that customer" do
            subject
            expect(Customers::RefreshWalletJob).not_to have_been_enqueued.with(target_customer)
          end
        end
      end
    end
  end
end
