# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "migrations:backfill_wallet_transactions_billing_entity" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["migrations:backfill_wallet_transactions_billing_entity"] }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:) }

  before do
    Rake.application.rake_require("tasks/migrations/wallet_transactions")
    Rake::Task.define_task(:environment)
    task.reenable

    allow(Kernel).to receive(:sleep)
  end

  context "when wallet transactions are missing a billing entity" do
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, organization:, billing_entity: nil) }

    it "backfills them from the customer billing entity" do
      wallet_transaction

      expect { perform_enqueued_jobs { task.invoke } }.to output(/All good/).to_stdout

      expect(wallet_transaction.reload.billing_entity_id).to eq(customer.billing_entity_id)
    end
  end

  context "when there is nothing to backfill" do
    it "reports nothing to do without enqueuing the job" do
      allow(DatabaseMigrations::BackfillWalletTransactionsBillingEntityJob).to receive(:perform_later)

      expect { task.invoke }.to output(/Nothing to do/).to_stdout

      expect(DatabaseMigrations::BackfillWalletTransactionsBillingEntityJob).not_to have_received(:perform_later)
    end
  end
end
