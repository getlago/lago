# frozen_string_literal: true

require "rails_helper"

describe "Events Targeting Wallets Scenarios", transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  describe "pay in arrears charges with wallet targeting", :premium do
    let(:plan) { create(:plan, organization:, amount_cents: 0) }
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        accepts_target_wallet: true,
        properties: {amount: "10"}
      )
    end

    let(:wallet1) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_1", name: "Wallet 1", balance_cents: 20_000, credits_balance: 200.0) }
    let(:wallet2) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_2", name: "Wallet 2", balance_cents: 25_000, credits_balance: 250.0) }

    before do
      organization.update!(premium_integrations: ["events_targeting_wallets"])
      charge
    end

    it "groups fees by target_wallet_code and applies credits from correct wallets" do
      jan15 = DateTime.new(2023, 1, 15)

      travel_to(jan15) do
        wallet1
        wallet2

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_wallet_test",
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.find_by(external_id: "sub_wallet_test")

      # Send events with different target_wallet_code values
      travel_to(jan15 + 1.day) do
        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "10", target_wallet_code: "wallet_1"}
        })

        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "5", target_wallet_code: "wallet_1"}
        })

        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "20", target_wallet_code: "wallet_2"}
        })

        # Refresh wallets to update ongoing balance
        recalculate_wallet_balances

        # Verify ongoing balance reflects targeted usage
        # wallet_1: 15 units * $10 = $150 ongoing usage
        expect(wallet1.reload.ongoing_usage_balance_cents).to eq(15_000)
        # wallet_2: 20 units * $10 = $200 ongoing usage
        expect(wallet2.reload.ongoing_usage_balance_cents).to eq(20_000)
      end

      # Bill the subscription at end of month
      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      # Verify invoice has correct grouped fees
      invoice = subscription.invoices.first
      expect(invoice).to be_present

      charge_fees = invoice.fees.charge
      expect(charge_fees.count).to eq(2)

      wallet1_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_1" }
      wallet2_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_2" }

      expect(wallet1_fee.units).to eq(15)
      expect(wallet1_fee.amount_cents).to eq(15_000)

      expect(wallet2_fee.units).to eq(20)
      expect(wallet2_fee.amount_cents).to eq(20_000)

      # Verify credits were applied from correct wallets
      expect(invoice.prepaid_credit_amount_cents).to eq(35_000)

      # wallet_1: had $200, used $150, should have $50 left
      expect(wallet1.reload.balance_cents).to eq(5_000)

      # wallet_2: had $250, used $200, should have $50 left
      expect(wallet2.reload.balance_cents).to eq(5_000)

      # Verify wallet transactions
      wallet1_tx = wallet1.wallet_transactions.where(invoice:)
      wallet2_tx = wallet2.wallet_transactions.where(invoice:)

      expect(wallet1_tx.count).to eq(1)
      expect(wallet1_tx.first.amount_cents).to eq(15_000)

      expect(wallet2_tx.count).to eq(1)
      expect(wallet2_tx.first.amount_cents).to eq(20_000)
    end

    context "with pricing_group_keys and wallet targeting combined" do
      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          accepts_target_wallet: true,
          properties: {
            amount: "5",
            pricing_group_keys: ["region"]
          }
        )
      end

      it "groups fees by both pricing_group_keys and target_wallet_code and applies credits correctly" do
        jan15 = DateTime.new(2023, 1, 15)

        travel_to(jan15) do
          wallet1
          wallet2

          create_subscription({
            external_customer_id: customer.external_id,
            external_id: "sub_combined",
            plan_code: plan.code
          })
        end

        subscription = customer.subscriptions.find_by(external_id: "sub_combined")

        # Send events with different combinations of region and target_wallet_code
        travel_to(jan15 + 1.day) do
          # wallet_1, region: eu - 10 units * $5 = $50
          create_event({
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {value: "10", region: "eu", target_wallet_code: "wallet_1"}
          })

          # wallet_1, region: us - 15 units * $5 = $75
          create_event({
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {value: "15", region: "us", target_wallet_code: "wallet_1"}
          })

          # wallet_2, region: eu - 20 units * $5 = $100
          create_event({
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {value: "20", region: "eu", target_wallet_code: "wallet_2"}
          })

          # Refresh wallets to check ongoing balance
          recalculate_wallet_balances

          # wallet_1: $50 (eu) + $75 (us) = $125 ongoing usage
          expect(wallet1.reload.ongoing_usage_balance_cents).to eq(12_500)
          # wallet_2: $100 (eu) ongoing usage
          expect(wallet2.reload.ongoing_usage_balance_cents).to eq(10_000)
        end

        # Bill at end of month
        travel_to(DateTime.new(2023, 2, 1)) do
          perform_billing
        end

        invoice = subscription.invoices.first
        charge_fees = invoice.fees.charge

        # Should have 3 fees: (wallet_1, eu), (wallet_1, us), (wallet_2, eu)
        expect(charge_fees.count).to eq(3)

        wallet1_eu_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_1" && f.grouped_by["region"] == "eu" }
        wallet1_us_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_1" && f.grouped_by["region"] == "us" }
        wallet2_eu_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_2" && f.grouped_by["region"] == "eu" }

        expect(wallet1_eu_fee.units).to eq(10)
        expect(wallet1_eu_fee.amount_cents).to eq(5_000)

        expect(wallet1_us_fee.units).to eq(15)
        expect(wallet1_us_fee.amount_cents).to eq(7_500)

        expect(wallet2_eu_fee.units).to eq(20)
        expect(wallet2_eu_fee.amount_cents).to eq(10_000)

        # Verify credits applied from correct wallets
        # wallet_1: had $200, used $125 ($50 + $75), should have $75 left
        expect(wallet1.reload.balance_cents).to eq(7_500)

        # wallet_2: had $250, used $100, should have $150 left
        expect(wallet2.reload.balance_cents).to eq(15_000)

        # Verify wallet transactions
        wallet1_tx = wallet1.wallet_transactions.where(invoice:)
        wallet2_tx = wallet2.wallet_transactions.where(invoice:)

        expect(wallet1_tx.count).to eq(1)
        expect(wallet1_tx.first.amount_cents).to eq(12_500)

        expect(wallet2_tx.count).to eq(1)
        expect(wallet2_tx.first.amount_cents).to eq(10_000)
      end
    end
  end

  describe "pay in advance charges with wallet targeting", :premium do
    let(:plan) { create(:plan, organization:, amount_cents: 0) }
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    let(:charge) do
      create(
        :standard_charge,
        :pay_in_advance,
        invoiceable: true,
        plan:,
        billable_metric:,
        accepts_target_wallet: true,
        properties: {amount: "10"}
      )
    end

    let(:wallet1) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_1", name: "Wallet 1", balance_cents: 15_000, credits_balance: 150.0) }
    let(:wallet2) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_2", name: "Wallet 2", balance_cents: 10_000, credits_balance: 100.0) }

    before do
      organization.update!(premium_integrations: ["events_targeting_wallets"])
      charge
    end

    it "creates pay_in_advance fees and deducts from correct wallets" do
      jan15 = DateTime.new(2023, 1, 15)

      travel_to(jan15) do
        wallet1
        wallet2

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_advance",
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.find_by(external_id: "sub_advance")

      # Send events - each should create a pay_in_advance fee and deduct from targeted wallet
      travel_to(jan15 + 1.day) do
        expect do
          create_event({
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {value: "10", target_wallet_code: "wallet_1"}
          })
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee1 = subscription.fees.order(created_at: :desc).first
        expect(fee1.pay_in_advance).to eq(true)
        expect(fee1.units).to eq(10)
        expect(fee1.amount_cents).to eq(10_000)
        expect(fee1.grouped_by["target_wallet_code"]).to eq("wallet_1")

        # wallet_1 should have $100 deducted (had $150, now $50)
        expect(wallet1.reload.balance_cents).to eq(5_000)
        # wallet_2 should be unchanged
        expect(wallet2.reload.balance_cents).to eq(10_000)
      end

      travel_to(jan15 + 2.days) do
        expect do
          create_event({
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {value: "5", target_wallet_code: "wallet_2"}
          })
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee2 = subscription.fees.order(created_at: :desc).first
        expect(fee2.pay_in_advance).to eq(true)
        expect(fee2.units).to eq(5)
        expect(fee2.amount_cents).to eq(5_000)
        expect(fee2.grouped_by["target_wallet_code"]).to eq("wallet_2")

        # wallet_1 should still have $50
        expect(wallet1.reload.balance_cents).to eq(5_000)
        # wallet_2 should have $50 deducted (had $100, now $50)
        expect(wallet2.reload.balance_cents).to eq(5_000)
      end
    end
  end

  describe "events without target_wallet_code on accepting charge", :premium do
    let(:plan) { create(:plan, organization:, amount_cents: 0) }
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        accepts_target_wallet: true,
        properties: {amount: "10"}
      )
    end

    let(:wallet1) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_1", name: "Wallet 1", balance_cents: 15_000, credits_balance: 150.0) }
    let(:default_wallet) { create(:wallet, :with_inbound_transaction, customer:, code: "default_wallet", name: "Default Wallet", balance_cents: 10_000, credits_balance: 100.0, priority: 1) }

    before do
      organization.update!(premium_integrations: ["events_targeting_wallets"])
      charge
    end

    it "applies credits from targeted wallet and default wallet for non-targeted fees" do
      jan15 = DateTime.new(2023, 1, 15)

      travel_to(jan15) do
        wallet1
        default_wallet

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_mixed",
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.find_by(external_id: "sub_mixed")

      travel_to(jan15 + 1.day) do
        # Event with wallet
        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "10", target_wallet_code: "wallet_1"}
        })

        # Event without wallet
        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "5"}
        })

        # Refresh wallets to check ongoing balance
        recalculate_wallet_balances

        # wallet_1 should have ongoing usage for targeted events
        expect(wallet1.reload.ongoing_usage_balance_cents).to eq(10_000)
        # default_wallet should have ongoing usage for non-targeted events
        expect(default_wallet.reload.ongoing_usage_balance_cents).to eq(5_000)
      end

      # Bill at end of month
      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      invoice = subscription.invoices.first
      charge_fees = invoice.fees.charge

      expect(charge_fees.count).to eq(2)

      wallet_fee = charge_fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_1" }
      no_wallet_fee = charge_fees.find { |f| f.grouped_by.empty? || f.grouped_by["target_wallet_code"].nil? }

      expect(wallet_fee.units).to eq(10)
      expect(wallet_fee.amount_cents).to eq(10_000)

      expect(no_wallet_fee.units).to eq(5)
      expect(no_wallet_fee.amount_cents).to eq(5_000)

      # wallet_1 should have $100 deducted for targeted fee (had $150, now $50)
      expect(wallet1.reload.balance_cents).to eq(5_000)

      # default_wallet should have $50 deducted for non-targeted fee (had $100, now $50)
      expect(default_wallet.reload.balance_cents).to eq(5_000)

      # Verify wallet transactions
      wallet1_tx = wallet1.wallet_transactions.where(invoice:)
      default_wallet_tx = default_wallet.wallet_transactions.where(invoice:)

      expect(wallet1_tx.count).to eq(1)
      expect(wallet1_tx.first.amount_cents).to eq(10_000)

      expect(default_wallet_tx.count).to eq(1)
      expect(default_wallet_tx.first.amount_cents).to eq(5_000)
    end
  end

  describe "events with target_wallet_code when feature is disabled", :premium do
    let(:plan) { create(:plan, organization:, amount_cents: 0) }
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        accepts_target_wallet: false,
        properties: {amount: "10"}
      )
    end

    let(:wallet1) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_1", name: "Wallet 1", balance_cents: 20_000, credits_balance: 200.0, priority: 1) }
    let(:wallet2) { create(:wallet, :with_inbound_transaction, customer:, code: "wallet_2", name: "Wallet 2", balance_cents: 25_000, credits_balance: 250.0, priority: 2) }

    before do
      # Organization does NOT have events_targeting_wallets enabled
      organization.update!(premium_integrations: [])
      charge
    end

    it "ignores target_wallet_code and applies standard wallet logic" do
      jan15 = DateTime.new(2023, 1, 15)

      travel_to(jan15) do
        wallet1
        wallet2

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_no_targeting",
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.find_by(external_id: "sub_no_targeting")

      # Send events with target_wallet_code - should be ignored
      travel_to(jan15 + 1.day) do
        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "10", target_wallet_code: "wallet_1"}
        })

        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "5", target_wallet_code: "wallet_1"}
        })

        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          properties: {value: "20", target_wallet_code: "wallet_2"}
        })

        # Refresh wallets
        recalculate_wallet_balances

        # Without wallet targeting, all usage should be attributed to oldest wallet (wallet1)
        # Total: 35 units * $10 = $350
        expect(wallet1.reload.ongoing_usage_balance_cents).to eq(35_000)
        expect(wallet2.reload.ongoing_usage_balance_cents).to eq(0)
      end

      # Bill at end of month
      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      invoice = subscription.invoices.first
      expect(invoice).to be_present

      charge_fees = invoice.fees.charge

      # Should have only 1 fee (not grouped by target_wallet_code)
      expect(charge_fees.count).to eq(1)

      fee = charge_fees.first
      expect(fee.units).to eq(35)
      expect(fee.amount_cents).to eq(35_000)
      expect(fee.grouped_by).to be_empty

      # Credits applied using standard logic - oldest wallet first (wallet1)
      # wallet1 had $200, total fee is $350, so wallet1 should be depleted
      expect(wallet1.reload.balance_cents).to eq(0)

      # Remaining $150 should come from wallet2 (had $250, now $100)
      expect(wallet2.reload.balance_cents).to eq(10_000)

      # Verify wallet transactions
      wallet1_tx = wallet1.wallet_transactions.where(invoice:)
      wallet2_tx = wallet2.wallet_transactions.where(invoice:)

      expect(wallet1_tx.count).to eq(1)
      expect(wallet1_tx.first.amount_cents).to eq(20_000)

      expect(wallet2_tx.count).to eq(1)
      expect(wallet2_tx.first.amount_cents).to eq(15_000)
    end
  end
end
