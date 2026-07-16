# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::TrackConsumptionService do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:, balance_cents: 10000, credits_balance: 100.0) }

  describe "#call" do
    subject(:result) { described_class.call(outbound_wallet_transaction:) }

    context "when consuming by priority" do
      let!(:inbound_granted) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 30,
          credit_amount: 30,
          remaining_amount_cents: 3000,
          priority: 10)
      end

      let!(:inbound_purchased) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 70,
          credit_amount: 70,
          remaining_amount_cents: 7000,
          priority: 10)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 50,
          credit_amount: 50)
      end

      it "creates consumption records following granted-first priority" do
        expect { result }.to change(WalletTransactionConsumption, :count).by(2)
      end

      it "consumes granted credits first" do
        result

        consumptions = outbound_wallet_transaction.fundings.order(:consumed_amount_cents)
        expect(consumptions.first.inbound_wallet_transaction).to eq(inbound_purchased)
        expect(consumptions.first.consumed_amount_cents).to eq(2000)

        expect(consumptions.second.inbound_wallet_transaction).to eq(inbound_granted)
        expect(consumptions.second.consumed_amount_cents).to eq(3000)
      end

      it "decrements remaining_amount_cents on inbound transactions" do
        result

        expect(inbound_granted.reload.remaining_amount_cents).to eq(0)
        expect(inbound_purchased.reload.remaining_amount_cents).to eq(5000)
      end

      it "returns a success result" do
        expect(result).to be_success
      end
    end

    context "when outbound amount exceeds available inbound amount" do
      let(:inbound_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 30,
          credit_amount: 30,
          remaining_amount_cents: 3000)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 50,
          credit_amount: 50)
      end

      before do
        inbound_transaction
      end

      it "does not create consumption records" do
        expect { result }.not_to change(WalletTransactionConsumption, :count)
      end

      it "returns a failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:amount_cents]).to eq(["exceeds_available_amount"])
      end
    end

    context "with multiple inbound transactions of different priorities" do
      let!(:inbound_low_priority) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 50,
          credit_amount: 50,
          remaining_amount_cents: 5000,
          priority: 20,
          created_at: 2.days.ago)
      end

      let!(:inbound_high_priority) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 50,
          credit_amount: 50,
          remaining_amount_cents: 5000,
          priority: 10,
          created_at: 1.day.ago)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 60,
          credit_amount: 60)
      end

      it "consumes from higher priority (lower number) first" do
        result

        expect(inbound_high_priority.reload.remaining_amount_cents).to eq(0)
        expect(inbound_low_priority.reload.remaining_amount_cents).to eq(4000)
      end
    end

    context "with inbound transactions of same priority but different created_at" do
      let!(:inbound_older) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 50,
          credit_amount: 50,
          remaining_amount_cents: 5000,
          priority: 10,
          created_at: 2.days.ago)
      end

      let!(:inbound_newer) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 50,
          credit_amount: 50,
          remaining_amount_cents: 5000,
          priority: 10,
          created_at: 1.day.ago)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 60,
          credit_amount: 60)
      end

      it "consumes from older transactions first (FIFO)" do
        result

        expect(inbound_older.reload.remaining_amount_cents).to eq(0)
        expect(inbound_newer.reload.remaining_amount_cents).to eq(4000)
      end
    end

    context "when no inbound transactions with remaining balance exist" do
      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 50,
          credit_amount: 50)
      end

      it "returns a failure result" do
        expect(result).to be_failure
        expect(result.error.messages[:amount_cents]).to eq(["exceeds_available_amount"])
      end
    end

    context "with full ordering: priority, then granted/purchased, then FIFO" do
      # Order should be:
      # 1. TX1: priority 1, granted (highest priority)
      # 2. TX2: priority 1, purchased (same priority as TX1, but purchased after granted)
      # 3. TX3: priority 2, granted, older (lower priority, but granted before purchased)
      # 4. TX4: priority 2, granted, newer (same as TX3 but newer - FIFO)
      # 5. TX5: priority 2, purchased (same priority as TX3/TX4, but purchased after granted)

      let!(:tx1_prio1_granted) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 1,
          created_at: 5.days.ago)
      end

      let!(:tx2_prio1_purchased) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 1,
          created_at: 4.days.ago)
      end

      let!(:tx3_prio2_granted_older) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 2,
          created_at: 3.days.ago)
      end

      let!(:tx4_prio2_granted_newer) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 2,
          created_at: 2.days.ago)
      end

      let!(:tx5_prio2_purchased) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 2,
          created_at: 1.day.ago)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 35,
          credit_amount: 35)
      end

      it "consumes in order: priority, then granted before purchased, then FIFO" do
        result

        # TX1 (prio 1, granted): fully consumed
        expect(tx1_prio1_granted.reload.remaining_amount_cents).to eq(0)
        # TX2 (prio 1, purchased): fully consumed
        expect(tx2_prio1_purchased.reload.remaining_amount_cents).to eq(0)
        # TX3 (prio 2, granted, older): fully consumed
        expect(tx3_prio2_granted_older.reload.remaining_amount_cents).to eq(0)
        # TX4 (prio 2, granted, newer): partially consumed (5 remaining)
        expect(tx4_prio2_granted_newer.reload.remaining_amount_cents).to eq(500)
        # TX5 (prio 2, purchased): not consumed yet
        expect(tx5_prio2_purchased.reload.remaining_amount_cents).to eq(1000)
      end

      it "creates consumption records for the correct inbound transactions" do
        result

        consumed_transactions = outbound_wallet_transaction.fundings.map(&:inbound_wallet_transaction)

        expect(consumed_transactions).to contain_exactly(
          tx1_prio1_granted,
          tx2_prio1_purchased,
          tx3_prio2_granted_older,
          tx4_prio2_granted_newer
        )
        # TX5 should NOT be consumed
        expect(consumed_transactions).not_to include(tx5_prio2_purchased)
      end
    end

    context "when outbound amount is zero" do
      let!(:inbound_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 100,
          credit_amount: 100,
          remaining_amount_cents: 10000)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :invoiced,
          status: :settled,
          amount: 0,
          credit_amount: 0)
      end

      it "does not create any consumption records" do
        expect { result }.not_to change(WalletTransactionConsumption, :count)
      end

      it "does not decrement inbound remaining_amount_cents" do
        result

        expect(inbound_transaction.reload.remaining_amount_cents).to eq(10000)
      end

      it "returns a success result" do
        expect(result).to be_success
      end
    end

    context "when consuming from specific inbound transaction" do
      subject(:result) do
        described_class.call(
          outbound_wallet_transaction:,
          inbound_wallet_transaction_id: specific_inbound.id
        )
      end

      let!(:specific_inbound) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 50,
          credit_amount: 50,
          remaining_amount_cents: 5000,
          priority: 50)
      end

      let!(:other_inbound) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 100,
          credit_amount: 100,
          remaining_amount_cents: 10000,
          priority: 1)
      end

      let(:outbound_wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :outbound,
          transaction_status: :voided,
          status: :settled,
          amount: 30,
          credit_amount: 30)
      end

      it "consumes from the specific inbound transaction ignoring priority" do
        result

        expect(specific_inbound.reload.remaining_amount_cents).to eq(2000)
        expect(other_inbound.reload.remaining_amount_cents).to eq(10000)
      end

      it "creates a single consumption record" do
        expect { result }.to change(WalletTransactionConsumption, :count).by(1)

        consumption = WalletTransactionConsumption.last
        expect(consumption.inbound_wallet_transaction).to eq(specific_inbound)
        expect(consumption.outbound_wallet_transaction).to eq(outbound_wallet_transaction)
        expect(consumption.consumed_amount_cents).to eq(3000)
      end

      it "returns a success result" do
        expect(result).to be_success
      end

      context "when outbound amount exceeds specific inbound remaining amount" do
        let(:outbound_wallet_transaction) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :outbound,
            transaction_status: :voided,
            status: :settled,
            amount: 60,
            credit_amount: 60)
        end

        it "does not create consumption records" do
          expect { result }.not_to change(WalletTransactionConsumption, :count)
        end

        it "returns a failure result with specific error" do
          expect(result).to be_failure
          expect(result.error.messages[:amount_cents]).to eq(["exceeds_remaining_transaction_amount"])
        end
      end

      context "when specific inbound has zero remaining amount" do
        let!(:specific_inbound) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 50,
            credit_amount: 50,
            remaining_amount_cents: 0)
        end

        let(:outbound_wallet_transaction) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :outbound,
            transaction_status: :voided,
            status: :settled,
            amount: 10,
            credit_amount: 10)
        end

        it "returns a failure result" do
          expect(result).to be_failure
          expect(result.error.messages[:amount_cents]).to eq(["exceeds_remaining_transaction_amount"])
        end
      end
    end
  end
end
