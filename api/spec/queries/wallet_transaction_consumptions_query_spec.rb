# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactionConsumptionsQuery do
  subject(:result) do
    described_class.call(
      organization:,
      pagination:,
      filters: {
        wallet_transaction_id:,
        direction:
      }
    )
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, traceable: true) }
  let(:pagination) { nil }

  describe "with invalid direction" do
    let(:direction) { "invalid" }
    let(:wallet_transaction_id) { SecureRandom.uuid }

    it "returns validation failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages).to include(:direction)
    end
  end

  describe "consumptions direction" do
    let(:direction) { "consumptions" }
    let(:wallet_transaction_id) { inbound_transaction.id }
    let(:inbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: "inbound", remaining_amount_cents: 10000) }

    context "with consumptions" do
      let(:outbound_transaction1) { create(:wallet_transaction, wallet:, transaction_type: "outbound") }
      let(:outbound_transaction2) { create(:wallet_transaction, wallet:, transaction_type: "outbound") }
      let(:consumption1) do
        create(:wallet_transaction_consumption,
          organization:,
          inbound_wallet_transaction: inbound_transaction,
          outbound_wallet_transaction: outbound_transaction1,
          consumed_amount_cents: 500)
      end
      let(:consumption2) do
        create(:wallet_transaction_consumption,
          organization:,
          inbound_wallet_transaction: inbound_transaction,
          outbound_wallet_transaction: outbound_transaction2,
          consumed_amount_cents: 300)
      end

      before do
        consumption1
        consumption2
      end

      it "returns consumptions for the inbound transaction" do
        expect(result).to be_success
        expect(result.wallet_transaction_consumptions.count).to eq(2)
        expect(result.wallet_transaction_consumptions.pluck(:id)).to match_array([consumption1.id, consumption2.id])
      end

      context "with pagination" do
        let(:pagination) { {page: 1, limit: 1} }

        it "applies pagination" do
          expect(result).to be_success
          expect(result.wallet_transaction_consumptions.count).to eq(1)
          expect(result.wallet_transaction_consumptions.current_page).to eq(1)
          expect(result.wallet_transaction_consumptions.total_pages).to eq(2)
          expect(result.wallet_transaction_consumptions.total_count).to eq(2)
        end
      end
    end

    context "when wallet_transaction is not found" do
      let(:wallet_transaction_id) { SecureRandom.uuid }

      it "returns not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("wallet_transaction_not_found")
      end
    end

    context "when wallet is not traceable" do
      let(:wallet) { create(:wallet, customer:, traceable: false) }

      it "returns validation error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({wallet: ["not_traceable"]})
      end
    end

    context "when transaction type is outbound" do
      let(:inbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: "outbound") }

      it "returns validation error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({transaction_type: ["invalid_transaction_type"]})
      end
    end
  end

  describe "fundings direction" do
    let(:direction) { "fundings" }
    let(:wallet_transaction_id) { outbound_transaction.id }
    let(:outbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: "outbound") }

    context "with fundings" do
      let(:inbound_transaction1) { create(:wallet_transaction, wallet:, transaction_type: "inbound", remaining_amount_cents: 10000) }
      let(:inbound_transaction2) { create(:wallet_transaction, wallet:, transaction_type: "inbound", remaining_amount_cents: 10000) }
      let(:funding1) do
        create(:wallet_transaction_consumption,
          organization:,
          inbound_wallet_transaction: inbound_transaction1,
          outbound_wallet_transaction: outbound_transaction,
          consumed_amount_cents: 500)
      end
      let(:funding2) do
        create(:wallet_transaction_consumption,
          organization:,
          inbound_wallet_transaction: inbound_transaction2,
          outbound_wallet_transaction: outbound_transaction,
          consumed_amount_cents: 300)
      end

      before do
        funding1
        funding2
      end

      it "returns fundings for the outbound transaction" do
        expect(result).to be_success
        expect(result.wallet_transaction_consumptions.count).to eq(2)
        expect(result.wallet_transaction_consumptions.pluck(:id)).to match_array([funding1.id, funding2.id])
      end

      context "with pagination" do
        let(:pagination) { {page: 1, limit: 1} }

        it "applies pagination" do
          expect(result).to be_success
          expect(result.wallet_transaction_consumptions.count).to eq(1)
          expect(result.wallet_transaction_consumptions.current_page).to eq(1)
          expect(result.wallet_transaction_consumptions.total_pages).to eq(2)
          expect(result.wallet_transaction_consumptions.total_count).to eq(2)
        end
      end
    end

    context "when wallet_transaction is not found" do
      let(:wallet_transaction_id) { SecureRandom.uuid }

      it "returns not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("wallet_transaction_not_found")
      end
    end

    context "when wallet is not traceable" do
      let(:wallet) { create(:wallet, customer:, traceable: false) }

      it "returns validation error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({wallet: ["not_traceable"]})
      end
    end

    context "when transaction type is inbound" do
      let(:outbound_transaction) { create(:wallet_transaction, wallet:, transaction_type: "inbound", remaining_amount_cents: 10000) }

      it "returns validation error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({transaction_type: ["invalid_transaction_type"]})
      end
    end
  end
end
