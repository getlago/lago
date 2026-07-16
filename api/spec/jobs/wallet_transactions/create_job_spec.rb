# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::CreateJob do
  subject(:create_job) { described_class }

  let(:organization) { create(:organization) }
  let(:wallet) { create(:wallet) }
  let(:wallet_transaction_create_service) { instance_double(WalletTransactions::CreateFromParamsService) }
  let(:params) do
    {
      wallet_id: wallet.id,
      paid_credits: "1.00",
      granted_credits: "1.00",
      source: "manual"
    }
  end

  it "calls the WalletTransactions::CreateFromParamsService" do
    allow(WalletTransactions::CreateFromParamsService).to receive(:call!)

    described_class.perform_now(organization_id: organization.id, params:)

    expect(WalletTransactions::CreateFromParamsService).to have_received(:call!).with(organization:, params:)
  end

  describe "#lock_key_arguments" do
    let(:organization_id) { "org-123" }
    let(:wallet_id) { "wallet-456" }
    let(:params) do
      {
        wallet_id: wallet_id,
        paid_credits: "10.0",
        granted_credits: "3.0",
        source: :threshold
      }
    end

    context "when unique_transaction is true" do
      it "returns a stable lock key array" do
        job = described_class.new
        allow(job).to receive(:arguments).and_return([{
          organization_id: organization_id,
          params: params,
          unique_transaction: true
        }])

        expect(job.lock_key_arguments).to eq([
          organization_id,
          wallet_id,
          "10.0",
          "3.0"
        ])
      end
    end
  end
end
