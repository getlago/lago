# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactionsQuery do
  subject(:result) do
    described_class.call(
      organization:,
      wallet_id: wallet_id,
      pagination:,
      filters:
    )
  end

  let(:returned_ids) { result.wallet_transactions.pluck(:id) }

  let(:wallet_id) { wallet.id }
  let(:pagination) { nil }
  let(:filters) { {} }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:) }
  let(:wallet_transaction_first) { create(:wallet_transaction, wallet:) }
  let(:wallet_transaction_second) { create(:wallet_transaction, wallet:) }
  let(:wallet_transaction_third) { create(:wallet_transaction, wallet:) }
  let(:wallet_transaction_fourth) { create(:wallet_transaction) }

  before do
    wallet_transaction_first
    wallet_transaction_second
    wallet_transaction_third
    wallet_transaction_fourth
  end

  it "returns all wallet transactions for a certain wallet" do
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(wallet_transaction_first.id)
    expect(returned_ids).to include(wallet_transaction_second.id)
    expect(returned_ids).to include(wallet_transaction_third.id)
    expect(returned_ids).not_to include(wallet_transaction_fourth.id)
  end

  context "when wallet transactions have the same values for the ordering criteria" do
    let(:wallet_transaction_second) do
      create(
        :wallet_transaction,
        wallet:,
        id: "00000000-0000-0000-0000-000000000000",
        created_at: wallet_transaction_first.created_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(3)
      expect(returned_ids).to include(wallet_transaction_first.id)
      expect(returned_ids).to include(wallet_transaction_second.id)
      expect(returned_ids.index(wallet_transaction_first.id)).to be > returned_ids.index(wallet_transaction_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.wallet_transactions.count).to eq(1)
      expect(result.wallet_transactions.current_page).to eq(2)
      expect(result.wallet_transactions.prev_page).to eq(1)
      expect(result.wallet_transactions.next_page).to be_nil
      expect(result.wallet_transactions.total_pages).to eq(2)
      expect(result.wallet_transactions.total_count).to eq(3)
    end
  end

  context "when filtering by status" do
    let(:wallet_transaction_third) { create(:wallet_transaction, wallet:, status: "pending") }

    let(:filters) { {status: "pending"} }

    it "returns only one wallet transaction" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).not_to include(wallet_transaction_first.id)
      expect(returned_ids).not_to include(wallet_transaction_second.id)
      expect(returned_ids).to include(wallet_transaction_third.id)
      expect(returned_ids).not_to include(wallet_transaction_fourth.id)
    end
  end

  context "when filtering by transaction type" do
    let(:wallet_transaction_third) { create(:wallet_transaction, wallet:, transaction_type: "outbound") }

    let(:filters) { {transaction_type: "outbound"} }

    it "returns only one wallet transaction" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).not_to include(wallet_transaction_first.id)
      expect(returned_ids).not_to include(wallet_transaction_second.id)
      expect(returned_ids).to include(wallet_transaction_third.id)
      expect(returned_ids).not_to include(wallet_transaction_fourth.id)
    end
  end

  context "when transaction_status filter is present" do
    # Override outer context transactions to avoid interference
    let(:wallet_transaction_first) { nil }
    let(:wallet_transaction_second) { nil }
    let(:wallet_transaction_third) { nil }

    let(:purchased_transaction) do
      create(:wallet_transaction, wallet:, transaction_status: :purchased)
    end
    let(:granted_transaction) do
      create(:wallet_transaction, wallet:, transaction_status: :granted)
    end
    let(:voided_transaction) do
      create(:wallet_transaction, wallet:, transaction_status: :voided)
    end
    let(:invoiced_transaction) do
      create(:wallet_transaction, wallet:, transaction_status: :invoiced)
    end

    before do
      purchased_transaction
      granted_transaction
      voided_transaction
      invoiced_transaction
    end

    context "with purchased status" do
      let(:filters) { {transaction_status: "purchased"} }

      it "returns only purchased transactions" do
        expect(result).to be_success
        expect(returned_ids).to eq([purchased_transaction.id])
      end
    end

    context "with granted status" do
      let(:filters) { {transaction_status: "granted"} }

      it "returns only granted transactions" do
        expect(result).to be_success
        expect(returned_ids).to eq([granted_transaction.id])
      end
    end

    context "with voided status" do
      let(:filters) { {transaction_status: "voided"} }

      it "returns only voided transactions" do
        expect(result).to be_success
        expect(returned_ids).to eq([voided_transaction.id])
      end
    end

    context "with invoiced status" do
      let(:filters) { {transaction_status: "invoiced"} }

      it "returns only invoiced transactions" do
        expect(result).to be_success
        expect(returned_ids).to eq([invoiced_transaction.id])
      end
    end

    context "with invalid transaction_status" do
      let(:filters) { {transaction_status: "invalid"} }

      it "returns all transactions" do
        expect(result).to be_success
        expect(returned_ids.count).to eq(4)
      end
    end
  end

  context "when wallet is not found" do
    let(:wallet_id) { "#{wallet.id}abc" }

    it "returns not found error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::NotFoundFailure)
      expect(result.error.message).to eq("wallet_not_found")
    end
  end
end
