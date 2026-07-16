# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::VoidService do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) do
    create(
      :wallet,
      customer:,
      balance_cents: 1000,
      credits_balance: 10.0,
      ongoing_balance_cents: 1000,
      credits_ongoing_balance: 10.0,
      traceable: false
    )
  end
  let(:credit_amount) { BigDecimal("10.00") }
  let(:wallet_credit) { WalletCredit.new(wallet:, credit_amount:) }

  before do
    subscription
  end

  describe "#call" do
    subject(:result) { described_class.call(wallet:, wallet_credit:, **args) }

    let(:args) { {} }

    context "when credits amount is zero" do
      let(:credit_amount) { BigDecimal("0.00") }

      it "does not create a wallet transaction" do
        expect { subject }.not_to change(WalletTransaction, :count)
      end
    end

    context "with minimum arguments" do
      it "creates a wallet transaction" do
        expect { subject }.to change(WalletTransaction, :count).by(1)
      end

      it "sets default values" do
        freeze_time do
          expect(result.wallet_transaction)
            .to be_a(WalletTransaction)
            .and be_persisted
            .and have_attributes(
              amount: 10,
              credit_amount: 10,
              transaction_type: "outbound",
              status: "settled",
              transaction_status: "voided",
              settled_at: Time.current,
              source: "manual",
              metadata: [],
              priority: 50,
              credit_note_id: nil,
              name: nil
            )
        end
      end

      it "updates wallet balance" do
        wallet = result.wallet_transaction.wallet

        expect(wallet.balance_cents).to eq(0)
        expect(wallet.credits_balance).to eq(0.0)
      end
    end

    context "with all arguments" do
      let(:metadata) { [{"key" => "valid_value", "value" => "also_valid"}] }
      let(:credit_note_id) { create(:credit_note, organization:).id }

      let(:args) do
        {
          metadata:,
          credit_note_id:,
          source: :threshold,
          priority: 25,
          name: "Void Transaction"
        }
      end

      it "creates a wallet transaction" do
        expect { subject }.to change(WalletTransaction, :count).by(1)
      end

      it "sets all attributes" do
        freeze_time do
          expect(result.wallet_transaction)
            .to be_a(WalletTransaction)
            .and be_persisted
            .and have_attributes(
              amount: 10,
              credit_amount: 10,
              transaction_type: "outbound",
              status: "settled",
              transaction_status: "voided",
              settled_at: Time.current,
              metadata:,
              credit_note_id:,
              source: "threshold",
              priority: 25,
              name: "Void Transaction"
            )
        end
      end

      it "updates wallet balance" do
        wallet = result.wallet_transaction.wallet

        expect(wallet.balance_cents).to eq(0)
        expect(wallet.credits_balance).to eq(0.0)
      end
    end

    context "with nil name" do
      let(:args) { {name: nil} }

      it "creates a wallet transaction with nil name" do
        expect(result.wallet_transaction.name).to be_nil
      end
    end

    context "with an inbound_wallet_transaction reference" do
      let(:original_billing_entity) { create(:billing_entity, organization:) }
      let(:new_billing_entity) { create(:billing_entity, organization:) }
      let(:inbound_wallet_transaction) do
        create(:wallet_transaction, wallet:, billing_entity: original_billing_entity)
      end
      let(:args) { {inbound_wallet_transaction:} }

      before do
        wallet.update!(billing_entity: new_billing_entity)
      end

      it "inherits the original transaction's billing entity, not the wallet's current one" do
        expect(result.wallet_transaction.billing_entity_id).to eq(original_billing_entity.id)
      end
    end

    context "when wallet is traceable" do
      let(:wallet) do
        create(
          :wallet,
          customer:,
          balance_cents: 1000,
          credits_balance: 10.0,
          ongoing_balance_cents: 1000,
          credits_ongoing_balance: 10.0,
          traceable: true
        )
      end

      let(:inbound_transaction) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000)
      end

      before do
        inbound_transaction
      end

      it "creates wallet transaction consumption records" do
        expect { subject }.to change(WalletTransactionConsumption, :count).by(1)

        expect(WalletTransactionConsumption.last).to have_attributes(
          inbound_wallet_transaction_id: inbound_transaction.id,
          outbound_wallet_transaction_id: result.wallet_transaction.id,
          consumed_amount_cents: 1000
        )

        expect(inbound_transaction.reload.remaining_amount_cents).to eq(0)
      end

      context "with multiple inbound transactions" do
        let(:wallet) do
          create(
            :wallet,
            customer:,
            balance_cents: 3000,
            credits_balance: 30.0,
            ongoing_balance_cents: 3000,
            credits_ongoing_balance: 30.0,
            traceable: true
          )
        end

        let(:credit_amount) { BigDecimal("25.00") }

        let!(:inbound_transaction_1) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 1000,
            priority: 50,
            created_at: 3.days.ago)
        end

        let!(:inbound_transaction_2) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 1000,
            priority: 50,
            created_at: 2.days.ago)
        end

        let!(:inbound_transaction_3) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 1000,
            priority: 50,
            created_at: 1.day.ago)
        end

        let(:inbound_transaction) { nil }

        it "consumes from multiple inbounds in order" do
          expect { subject }.to change(WalletTransactionConsumption, :count).by(3)

          consumptions = WalletTransactionConsumption.order(:created_at)

          expect(consumptions[0]).to have_attributes(
            inbound_wallet_transaction_id: inbound_transaction_1.id,
            consumed_amount_cents: 1000
          )
          expect(consumptions[1]).to have_attributes(
            inbound_wallet_transaction_id: inbound_transaction_2.id,
            consumed_amount_cents: 1000
          )
          expect(consumptions[2]).to have_attributes(
            inbound_wallet_transaction_id: inbound_transaction_3.id,
            consumed_amount_cents: 500
          )

          expect(inbound_transaction_1.reload.remaining_amount_cents).to eq(0)
          expect(inbound_transaction_2.reload.remaining_amount_cents).to eq(0)
          expect(inbound_transaction_3.reload.remaining_amount_cents).to eq(500)
        end
      end

      context "with partially consumed inbound transaction" do
        let(:wallet) do
          create(
            :wallet,
            customer:,
            balance_cents: 500,
            credits_balance: 5.0,
            ongoing_balance_cents: 500,
            credits_ongoing_balance: 5.0,
            traceable: true
          )
        end

        let(:credit_amount) { BigDecimal("5.00") }

        let!(:partially_consumed_inbound) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 500,
            priority: 50)
        end

        let(:inbound_transaction) { nil }

        it "consumes from the remaining amount only" do
          expect { subject }.to change(WalletTransactionConsumption, :count).by(1)

          expect(WalletTransactionConsumption.last).to have_attributes(
            inbound_wallet_transaction_id: partially_consumed_inbound.id,
            consumed_amount_cents: 500
          )

          expect(partially_consumed_inbound.reload.remaining_amount_cents).to eq(0)
        end
      end

      context "with fully consumed inbound transaction" do
        let(:wallet) do
          create(
            :wallet,
            customer:,
            balance_cents: 1000,
            credits_balance: 10.0,
            ongoing_balance_cents: 1000,
            credits_ongoing_balance: 10.0,
            traceable: true
          )
        end

        let!(:fully_consumed_inbound) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 0,
            priority: 50,
            created_at: 2.days.ago)
        end

        let!(:available_inbound) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 1000,
            priority: 50,
            created_at: 1.day.ago)
        end

        let(:inbound_transaction) { nil }

        it "skips fully consumed inbound and consumes from available one" do
          expect { subject }.to change(WalletTransactionConsumption, :count).by(1)

          expect(WalletTransactionConsumption.last).to have_attributes(
            inbound_wallet_transaction_id: available_inbound.id,
            consumed_amount_cents: 1000
          )

          expect(fully_consumed_inbound.reload.remaining_amount_cents).to eq(0)
          expect(available_inbound.reload.remaining_amount_cents).to eq(0)
        end
      end

      context "with priority rules" do
        let(:wallet) do
          create(
            :wallet,
            customer:,
            balance_cents: 8000,
            credits_balance: 80.0,
            ongoing_balance_cents: 8000,
            credits_ongoing_balance: 80.0,
            traceable: true
          )
        end

        let(:credit_amount) { BigDecimal("80.00") }
        let(:inbound_transaction) { nil }

        context "when granted credits have higher priority than purchased" do
          let!(:purchased_inbound) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :purchased,
              status: :settled,
              amount: 30,
              credit_amount: 30,
              remaining_amount_cents: 3000,
              priority: 50,
              created_at: 3.days.ago)
          end

          let!(:granted_inbound) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 50,
              credit_amount: 50,
              remaining_amount_cents: 5000,
              priority: 50,
              created_at: 1.day.ago)
          end

          it "consumes granted credits before purchased credits at same priority" do
            expect { subject }.to change(WalletTransactionConsumption, :count).by(2)

            consumptions = WalletTransactionConsumption.order(:created_at)

            expect(consumptions[0]).to have_attributes(
              inbound_wallet_transaction_id: granted_inbound.id,
              consumed_amount_cents: 5000
            )
            expect(consumptions[1]).to have_attributes(
              inbound_wallet_transaction_id: purchased_inbound.id,
              consumed_amount_cents: 3000
            )
          end
        end

        context "when lower priority number takes precedence" do
          let!(:low_priority_purchased) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :purchased,
              status: :settled,
              amount: 20,
              credit_amount: 20,
              remaining_amount_cents: 2000,
              priority: 1,
              created_at: 3.days.ago)
          end

          let!(:high_priority_granted) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 60,
              credit_amount: 60,
              remaining_amount_cents: 6000,
              priority: 50,
              created_at: 1.day.ago)
          end

          it "consumes lower priority number first regardless of transaction status" do
            expect { subject }.to change(WalletTransactionConsumption, :count).by(2)

            consumptions = WalletTransactionConsumption.order(:created_at)

            expect(consumptions[0]).to have_attributes(
              inbound_wallet_transaction_id: low_priority_purchased.id,
              consumed_amount_cents: 2000
            )
            expect(consumptions[1]).to have_attributes(
              inbound_wallet_transaction_id: high_priority_granted.id,
              consumed_amount_cents: 6000
            )
          end
        end

        context "when same priority and same transaction status" do
          let!(:older_granted) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 25,
              credit_amount: 25,
              remaining_amount_cents: 2500,
              priority: 2,
              created_at: 3.days.ago)
          end

          let!(:newer_granted) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 25,
              credit_amount: 25,
              remaining_amount_cents: 2500,
              priority: 2,
              created_at: 1.day.ago)
          end

          let!(:purchased) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :purchased,
              status: :settled,
              amount: 30,
              credit_amount: 30,
              remaining_amount_cents: 3000,
              priority: 2,
              created_at: 2.days.ago)
          end

          it "consumes older transactions first within same priority and status" do
            expect { subject }.to change(WalletTransactionConsumption, :count).by(3)

            consumptions = WalletTransactionConsumption.order(:created_at)

            expect(consumptions[0]).to have_attributes(
              inbound_wallet_transaction_id: older_granted.id,
              consumed_amount_cents: 2500
            )
            expect(consumptions[1]).to have_attributes(
              inbound_wallet_transaction_id: newer_granted.id,
              consumed_amount_cents: 2500
            )
            expect(consumptions[2]).to have_attributes(
              inbound_wallet_transaction_id: purchased.id,
              consumed_amount_cents: 3000
            )
          end
        end

        context "with complex priority scenario from spec" do
          # Customer has: $20 granted (priority 1), $25 granted (priority 2 created 3 days ago),
          # $25 granted (priority 2 created 1 day ago), $30 purchased (priority 2).
          # Then consumes $80

          let!(:tx1_granted_prio1) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 20,
              credit_amount: 20,
              remaining_amount_cents: 2000,
              priority: 1,
              created_at: 4.days.ago)
          end

          let!(:tx2_granted_prio2_oldest) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 25,
              credit_amount: 25,
              remaining_amount_cents: 2500,
              priority: 2,
              created_at: 3.days.ago)
          end

          let!(:tx3_granted_prio2_newer) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :granted,
              status: :settled,
              amount: 25,
              credit_amount: 25,
              remaining_amount_cents: 2500,
              priority: 2,
              created_at: 1.day.ago)
          end

          let!(:tx4_purchased_prio2) do
            create(:wallet_transaction,
              wallet:,
              organization:,
              transaction_type: :inbound,
              transaction_status: :purchased,
              status: :settled,
              amount: 30,
              credit_amount: 30,
              remaining_amount_cents: 3000,
              priority: 2,
              created_at: 2.days.ago)
          end

          it "consumes in correct order: prio1 -> prio2 granted oldest -> prio2 granted newer -> prio2 purchased" do
            expect { subject }.to change(WalletTransactionConsumption, :count).by(4)

            consumptions = WalletTransactionConsumption.order(:created_at)

            expect(consumptions[0]).to have_attributes(
              inbound_wallet_transaction_id: tx1_granted_prio1.id,
              consumed_amount_cents: 2000
            )
            expect(consumptions[1]).to have_attributes(
              inbound_wallet_transaction_id: tx2_granted_prio2_oldest.id,
              consumed_amount_cents: 2500
            )
            expect(consumptions[2]).to have_attributes(
              inbound_wallet_transaction_id: tx3_granted_prio2_newer.id,
              consumed_amount_cents: 2500
            )
            expect(consumptions[3]).to have_attributes(
              inbound_wallet_transaction_id: tx4_purchased_prio2.id,
              consumed_amount_cents: 1000
            )

            expect(tx1_granted_prio1.reload.remaining_amount_cents).to eq(0)
            expect(tx2_granted_prio2_oldest.reload.remaining_amount_cents).to eq(0)
            expect(tx3_granted_prio2_newer.reload.remaining_amount_cents).to eq(0)
            expect(tx4_purchased_prio2.reload.remaining_amount_cents).to eq(2000)
          end
        end
      end

      context "when void amount exceeds available balance" do
        let(:wallet) do
          create(
            :wallet,
            customer:,
            balance_cents: 500,
            credits_balance: 5.0,
            ongoing_balance_cents: 500,
            credits_ongoing_balance: 5.0,
            traceable: true
          )
        end

        let(:credit_amount) { BigDecimal("10.00") }

        let(:limited_inbound) do
          create(:wallet_transaction,
            wallet:,
            organization:,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 5,
            credit_amount: 5,
            remaining_amount_cents: 500,
            priority: 50)
        end

        let(:inbound_transaction) { nil }

        before { limited_inbound }

        it "raises a validation error and does not create consumption records" do
          expect { subject }.to raise_error(BaseService::ValidationFailure).and not_change(WalletTransactionConsumption, :count)
        end
      end
    end

    context "when wallet is not traceable" do
      let(:wallet) do
        create(
          :wallet,
          customer:,
          balance_cents: 1000,
          credits_balance: 10.0,
          ongoing_balance_cents: 1000,
          credits_ongoing_balance: 10.0,
          traceable: false
        )
      end

      it "does not create wallet transaction consumption records" do
        expect { subject }.not_to change(WalletTransactionConsumption, :count)
      end
    end

    context "when there is a concurrent lock" do
      before do
        stub_const("Customers::LockService::ACQUIRE_LOCK_TIMEOUT", 1.second)
      end

      around do |test|
        with_advisory_lock("customer-#{customer.id}-prepaid_credit", lock_released_after:) do
          test.run
        end
      end

      context "when it fails to acquire the lock" do
        let(:lock_released_after) { 2.seconds }

        it "raises a Customers::FailedToAcquireLock error" do
          expect { subject }.to raise_error(Customers::FailedToAcquireLock)
        end
      end

      context "when the lock is acquired" do
        let(:lock_released_after) { 0.6.seconds }

        it "voids the wallet transaction successfully" do
          expect { subject }.not_to raise_error
        end
      end
    end

    context "with inbound_wallet_transaction parameter" do
      let(:wallet) do
        create(
          :wallet,
          customer:,
          balance_cents: 3000,
          credits_balance: 30.0,
          ongoing_balance_cents: 3000,
          credits_ongoing_balance: 30.0,
          traceable: true
        )
      end

      let(:credit_amount) { BigDecimal("10.00") }

      let!(:specific_inbound) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 20,
          credit_amount: 20,
          remaining_amount_cents: 2000,
          priority: 50)
      end

      let!(:higher_priority_inbound) do
        create(:wallet_transaction,
          wallet:,
          organization:,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000,
          priority: 1)
      end

      let(:args) { {inbound_wallet_transaction: specific_inbound} }

      it "consumes from the specific inbound transaction" do
        expect { subject }.to change(WalletTransactionConsumption, :count).by(1)

        consumption = WalletTransactionConsumption.last
        expect(consumption.inbound_wallet_transaction).to eq(specific_inbound)
        expect(consumption.consumed_amount_cents).to eq(1000)

        expect(specific_inbound.reload.remaining_amount_cents).to eq(1000)
        expect(higher_priority_inbound.reload.remaining_amount_cents).to eq(1000)
      end

      context "when void amount exceeds specific inbound remaining amount" do
        let(:credit_amount) { BigDecimal("25.00") }

        it "returns a validation failure" do
          expect(subject).not_to be_success
          expect(subject.error).to be_a(BaseService::ValidationFailure)
          expect(subject.error.messages[:amount_cents]).to eq(["exceeds_remaining_transaction_amount"])
        end

        it "does not create a wallet transaction" do
          expect { subject }.not_to change(WalletTransaction, :count)
        end

        it "does not affect wallet balance" do
          expect { subject }.not_to change { wallet.reload.balance_cents }
        end
      end
    end
  end
end
