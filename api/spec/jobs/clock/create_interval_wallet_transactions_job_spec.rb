# frozen_string_literal: true

require "rails_helper"

describe Clock::CreateIntervalWalletTransactionsJob, job: true do
  subject(:interval_wallet_transactions_job) { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    before { allow(Wallets::CreateIntervalWalletTransactionsService).to receive(:call) }

    it "removes all old webhooks" do
      interval_wallet_transactions_job.perform_now

      expect(Wallets::CreateIntervalWalletTransactionsService).to have_received(:call)
    end
  end
end
