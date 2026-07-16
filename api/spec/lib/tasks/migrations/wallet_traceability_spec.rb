# frozen_string_literal: true

require "rails_helper"
require "rake"

describe "migrations:wallet_traceability", type: :request, with_pdf_generation_stub: true do
  let(:task) { Rake::Task["migrations:wallet_traceability"] }
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 0) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 0, pay_in_advance: false) }
  let(:billable_metric) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
  let(:charge) { create(:charge, plan:, billable_metric:, charge_model: "standard", properties: {"amount" => "1"}) }

  before do
    charge
    Rake.application.rake_require("tasks/migrations/wallet_traceability")
    Rake::Task.define_task(:environment)
    task.reenable
  end

  def create_non_traceable_wallet(for_customer: customer, rate_amount: "1", name: "Non-Traceable Wallet")
    params = {
      external_customer_id: for_customer.external_id,
      rate_amount:,
      name:,
      currency: "EUR",
      granted_credits: "0",
      invoice_requires_successful_payment: false
    }

    wallet = create_wallet(params, as: :model)
    wallet.update!(traceable: false)
    wallet
  end

  def top_up_wallet(wallet, granted_credits: nil, paid_credits: nil)
    params = {wallet_id: wallet.id}
    params[:granted_credits] = granted_credits if granted_credits
    params[:paid_credits] = paid_credits if paid_credits

    create_wallet_transaction(params, as: :model)
  end

  def setup_subscription
    create_subscription({
      external_customer_id: customer.external_id,
      external_id: customer.external_id,
      plan_code: plan.code
    })
    customer.subscriptions.first
  end

  def ingest_usage(subscription, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric.field_name => amount}
    })
    perform_usage_update
  end

  def run_migration(dry_run: nil, include_terminated: false, silent: true)
    env_vars = {
      "ORGANIZATION_ID" => organization.id,
      "BATCH_SIZE" => "100",
      "ERROR_DISPLAY_LIMIT" => "50"
    }
    env_vars["DRY_RUN"] = "false" if dry_run == false
    env_vars["INCLUDE_TERMINATED"] = "true" if include_terminated

    env_vars.each { |k, v| ENV[k] = v }
    task.reenable
    if silent
      original_stdout = $stdout
      $stdout = StringIO.new
      begin
        task.invoke
      ensure
        $stdout = original_stdout
      end
    else
      task.invoke
    end
  ensure
    env_vars&.each_key { |k| ENV.delete(k) }
  end

  describe "ENV var defaults" do
    it "defaults to dry-run when dry_run is not set" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["ORGANIZATION_ID"] = organization.id
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallet.reload.traceable).to eq(false)
    ensure
      ENV.delete("ORGANIZATION_ID")
    end

    it "processes all organizations when organization_id is not set" do
      other_organization = create(:organization, webhook_url: nil)
      other_billing_entity = create(:billing_entity, organization: other_organization, invoice_grace_period: 0)
      other_customer = create(:customer, organization: other_organization, billing_entity: other_billing_entity)

      wallet1 = create_non_traceable_wallet
      top_up_wallet(wallet1, granted_credits: "50")

      params = {
        external_customer_id: other_customer.external_id,
        rate_amount: "1",
        name: "Other Org Wallet",
        currency: "EUR",
        granted_credits: "0",
        invoice_requires_successful_payment: false
      }
      api_call { post_with_token(other_organization, "/api/v1/wallets", {wallet: params}) }
      wallet2 = Wallet.find(json[:wallet][:lago_id])
      api_call do
        post_with_token(other_organization, "/api/v1/wallet_transactions", {
          wallet_transaction: {wallet_id: wallet2.id, granted_credits: "30"}
        })
      end

      ENV["DRY_RUN"] = "false"
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallet1.reload.traceable).to eq(true)
      expect(wallet2.reload.traceable).to eq(true)
    ensure
      ENV.delete("DRY_RUN")
    end

    it "passes thread_count env var to migration" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["THREAD_COUNT"] = "4"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Threads: 4")).to_stdout

      expect(wallet.reload.traceable).to eq(false)
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("THREAD_COUNT")
    end

    it "caps batch_size to limit when both are set and batch_size exceeds limit" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["LIMIT"] = "5"
      ENV["BATCH_SIZE"] = "100"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Customer limit: 5, Batch size: 5")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("LIMIT")
      ENV.delete("BATCH_SIZE")
    end

    it "keeps batch_size when it is smaller than limit" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["LIMIT"] = "100"
      ENV["BATCH_SIZE"] = "10"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Customer limit: 100, Batch size: 10")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("LIMIT")
      ENV.delete("BATCH_SIZE")
    end

    it "does not cap batch_size when limit is not set" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["BATCH_SIZE"] = "500"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Customer limit: all, Batch size: 500")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("BATCH_SIZE")
    end

    it "cursor processes customers from the given customer_id (inclusive)" do
      other_customer = create(:customer, organization:, billing_entity:)
      wallet1 = create_non_traceable_wallet
      top_up_wallet(wallet1, granted_credits: "50")

      wallet2 = create_non_traceable_wallet(for_customer: other_customer, name: "Other Wallet")
      top_up_wallet(wallet2, granted_credits: "30")

      _, second_id = [customer.id, other_customer.id].sort
      ENV["DRY_RUN"] = "false"
      ENV["CURSOR"] = second_id
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      first_wallet = (customer.id == second_id) ? wallet1 : wallet2
      second_wallet = (customer.id == second_id) ? wallet2 : wallet1

      expect(first_wallet.reload.traceable).to eq(true)
      expect(second_wallet.reload.traceable).to eq(false)
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("CURSOR")
    end

    it "prints next cursor when limit is set and more records exist" do
      other_customer = create(:customer, organization:, billing_entity:)
      create_non_traceable_wallet
      create_non_traceable_wallet(for_customer: other_customer, name: "Other Wallet")

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["LIMIT"] = "1"
      task.reenable

      second_customer_id = [customer.id, other_customer.id].max
      expect { task.invoke }.to output(a_string_including("Next cursor: #{second_customer_id}")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("LIMIT")
    end

    it "does not print next cursor when all records fit within limit" do
      create_non_traceable_wallet

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["LIMIT"] = "100"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Next cursor: none (all remaining records fit within limit)")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("LIMIT")
    end

    it "prints next cursor accounting for cursor offset" do
      other_customer = create(:customer, organization:, billing_entity:)
      third_customer = create(:customer, organization:, billing_entity:)
      create_non_traceable_wallet
      create_non_traceable_wallet(for_customer: other_customer, name: "Wallet")
      create_non_traceable_wallet(for_customer: third_customer, name: "Wallet")

      sorted_ids = [customer.id, other_customer.id, third_customer.id].sort
      ENV["ORGANIZATION_ID"] = organization.id
      ENV["CURSOR"] = sorted_ids[1]
      ENV["LIMIT"] = "1"
      task.reenable

      expect { task.invoke }.to output(
        a_string_including("Cursor: #{sorted_ids[1]}").and(a_string_including("Next cursor: #{sorted_ids[2]}"))
      ).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("CURSOR")
      ENV.delete("LIMIT")
    end

    it "re-running a cursor window after next cursor was processed is a no-op" do
      other_customer = create(:customer, organization:, billing_entity:)
      wallet1 = create_non_traceable_wallet
      top_up_wallet(wallet1, granted_credits: "50")

      wallet2 = create_non_traceable_wallet(for_customer: other_customer, name: "Other Wallet")
      top_up_wallet(wallet2, granted_credits: "30")

      first_id, second_id = [customer.id, other_customer.id].sort
      first_wallet = (customer.id == first_id) ? wallet1 : wallet2
      second_wallet = (customer.id == first_id) ? wallet2 : wallet1

      # Run first window: processes first customer only
      ENV["DRY_RUN"] = "false"
      ENV["CURSOR"] = first_id
      ENV["LIMIT"] = "1"
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(first_wallet.reload.traceable).to eq(true)
      expect(second_wallet.reload.traceable).to eq(false)

      # Run second window: processes second customer
      ENV["CURSOR"] = second_id
      ENV.delete("LIMIT")
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(second_wallet.reload.traceable).to eq(true)

      # Re-run first window: should be a no-op since wallets are already traceable
      ENV["CURSOR"] = first_id
      ENV["LIMIT"] = "1"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Customers processed: 0")).to_stdout
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("CURSOR")
      ENV.delete("LIMIT")
    end

    it "re-running a cursor window processes remaining non-traceable wallets" do
      customer_b = create(:customer, organization:, billing_entity:)
      customer_c = create(:customer, organization:, billing_entity:)

      wallet1 = create_non_traceable_wallet
      top_up_wallet(wallet1, granted_credits: "50")

      wallet2 = create_non_traceable_wallet(for_customer: customer_b, name: "Wallet B")
      top_up_wallet(wallet2, granted_credits: "30")

      wallet3 = create_non_traceable_wallet(for_customer: customer_c, name: "Wallet C")
      top_up_wallet(wallet3, granted_credits: "20")

      first_id, second_id, third_id = [customer.id, customer_b.id, customer_c.id].sort
      wallets_by_customer = {customer.id => wallet1, customer_b.id => wallet2, customer_c.id => wallet3}

      # Run first window: processes first customer only
      ENV["DRY_RUN"] = "false"
      ENV["CURSOR"] = first_id
      ENV["LIMIT"] = "1"
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallets_by_customer[first_id].reload.traceable).to eq(true)
      expect(wallets_by_customer[second_id].reload.traceable).to eq(false)
      expect(wallets_by_customer[third_id].reload.traceable).to eq(false)

      # Run second window: processes second customer only
      ENV["CURSOR"] = second_id
      ENV["LIMIT"] = "1"
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallets_by_customer[second_id].reload.traceable).to eq(true)
      expect(wallets_by_customer[third_id].reload.traceable).to eq(false)

      # Re-run first cursor: the traceable: false scope shifts the window,
      # so the third customer (still non-traceable) falls into the LIMIT=1 window
      ENV["CURSOR"] = first_id
      ENV["LIMIT"] = "1"
      task.reenable

      expect { task.invoke }.to output(
        a_string_including("Customers processed: 1").and(a_string_including("Wallets processed: 1"))
      ).to_stdout
      expect(wallets_by_customer[third_id].reload.traceable).to eq(true)
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("CURSOR")
      ENV.delete("LIMIT")
    end

    it "processes nothing when cursor is past all customer_ids" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "50")

      # Use a UUID that sorts after all real customer_ids
      ENV["DRY_RUN"] = "false"
      ENV["CURSOR"] = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallet.reload.traceable).to eq(false)
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("CURSOR")
    end

    it "displays current cursor in header" do
      create_non_traceable_wallet

      ENV["ORGANIZATION_ID"] = organization.id
      ENV["CURSOR"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      task.reenable

      expect { task.invoke }.to output(a_string_including("Cursor: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
      ENV.delete("CURSOR")
    end

    it "defaults cursor to the first customer_id when not set" do
      create_non_traceable_wallet

      ENV["ORGANIZATION_ID"] = organization.id
      task.reenable

      expect { task.invoke }.to output(a_string_including("Cursor: #{customer.id}")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
    end

    it "does not print next cursor line when limit is not set" do
      create_non_traceable_wallet

      ENV["ORGANIZATION_ID"] = organization.id
      task.reenable

      expect { task.invoke }.not_to output(a_string_including("Next cursor:")).to_stdout
    ensure
      ENV.delete("ORGANIZATION_ID")
    end

    it "does not print next cursor line when only cursor is set without limit" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "50")

      ENV["DRY_RUN"] = "false"
      ENV["CURSOR"] = "00000000-0000-0000-0000-000000000000"
      task.reenable

      expect { task.invoke }.not_to output(a_string_including("Next cursor:")).to_stdout
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("CURSOR")
    end

    it "defaults to dry-run even when dry_run is set to any value other than 'false'" do
      wallet = create_non_traceable_wallet
      top_up_wallet(wallet, granted_credits: "100")

      ENV["DRY_RUN"] = "true"
      ENV["ORGANIZATION_ID"] = organization.id
      task.reenable
      expect { task.invoke }.to output(anything).to_stdout

      expect(wallet.reload.traceable).to eq(false)
    ensure
      ENV.delete("DRY_RUN")
      ENV.delete("ORGANIZATION_ID")
    end
  end

  describe "Dry-run mode" do
    describe "migratable wallet" do
      it "validates a wallet with consistent balance without modifying data" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 40)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        expect {
          run_migration
        }.not_to change {
                   [
                     WalletTransactionConsumption.count,
                     wallet.reload.traceable,
                     wallet.wallet_transactions.inbound.first.remaining_amount_cents
                   ]
                 }
      end
    end

    describe "CSV export on problematic wallets" do
      it "exports problematic wallets to CSV when output_file is set" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")

        # Manually corrupt the balance to create drift
        Wallet.where(id: wallet.id).update_all(balance_cents: 5000, credits_balance: 50) # rubocop:disable Rails/SkipsModelValidations

        Tempfile.create(["problematic_wallets", ".csv"]) do |tmpfile|
          env_vars = {
            "ORGANIZATION_ID" => organization.id,
            "BATCH_SIZE" => "100",
            "ERROR_DISPLAY_LIMIT" => "50",
            "ERROR_LOG_FILE" => tmpfile.path
          }
          env_vars.each { |k, v| ENV[k] = v }
          task.reenable
          expect { task.invoke }.to output(anything).to_stdout

          rows = CSV.read(tmpfile.path, headers: true)
          expect(rows.headers).to eq(%w[wallet_id customer_id customer_name organization_id organization_name created_at issues])
          expect(rows.size).to eq(1)
          row = rows.first
          expect(row["wallet_id"]).to eq(wallet.id)
          expect(row["customer_id"]).to eq(customer.id)
          expect(row["customer_name"]).to eq(customer.name)
          expect(row["organization_id"]).to eq(organization.id)
          expect(row["organization_name"]).to eq(organization.name)
          expect(row["created_at"]).to eq(wallet.created_at.to_date.to_s)
          expect(row["issues"]).to include("Balance drift")
        ensure
          env_vars&.each_key { |k| ENV.delete(k) }
        end
      end
    end

    describe "wallet with balance drift" do
      it "detects balance drift >= 1 unit and reports it as problematic" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")

        # Manually corrupt the balance to create drift
        Wallet.where(id: wallet.id).update_all(balance_cents: 5000, credits_balance: 50) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("Balance drift >= 1 unit"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end

      it "detects balance drift < 1 unit as likely rounding" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")

        # Small drift (50 cents) — below 100 cent threshold
        Wallet.where(id: wallet.id).update_all(balance_cents: 10050, credits_balance: 100.50) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("Balance drift < 1 unit"))
            .and(a_string_including("likely rounding"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end
    end

    describe "negative wallet balance" do
      it "detects negative wallet balance as problematic" do
        wallet = create_non_traceable_wallet

        Wallet.where(id: wallet.id).update_all(balance_cents: -500, credits_balance: -5) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("Negative wallet balance"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end
    end

    describe "missing inbound transactions" do
      it "detects outbound without any inbound as problematic" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :invoiced)

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("missing transaction history"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end
    end

    describe "negative transaction amount" do
      it "detects negative amount_cents on inbound transaction" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00",
          balance_cents: 0, credits_balance: 0)
        create(:wallet_transaction, wallet:, organization:,
          transaction_type: :inbound, status: :settled, amount: "-10.00", credit_amount: "-10.00",
          transaction_status: :granted, remaining_amount_cents: nil)

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("Negative amount_cents on inbound"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end

      it "detects negative amount_cents on outbound transaction" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00",
          balance_cents: 0, credits_balance: 0)
        create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "-10.00", credit_amount: "-10.00",
          transaction_status: :invoiced)

        expect {
          run_migration(silent: false)
        }.to output(
          a_string_including("Problematic: 1").and(a_string_including("Negative amount_cents on outbound"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end
    end
  end

  describe "Backfill mode" do
    describe "simple consumption" do
      # Customer tops up $100, then invoice consumes $40.
      # After backfill:
      # - One WalletTransactionConsumption: TX1 -> TX2 for $40
      # - TX1.remaining_amount_cents = 6000
      # - Wallet marked traceable

      it "creates consumption records and marks wallet traceable" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 40)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx1 = wallet.wallet_transactions.inbound.settled.first
        tx2 = wallet.wallet_transactions.outbound.settled.first
        expect(tx2).to be_present

        run_migration(dry_run: false)

        wallet.reload
        expect(wallet.traceable).to eq(true)

        expect(tx1.reload.remaining_amount_cents).to eq(6000)

        consumptions = WalletTransactionConsumption.where(
          inbound_wallet_transaction_id: tx1.id,
          outbound_wallet_transaction_id: tx2.id
        )
        expect(consumptions.count).to eq(1)
        expect(consumptions.first.consumed_amount_cents).to eq(4000)
      end
    end

    describe "consumption spanning multiple inbounds (FIFO)" do
      # Customer has two top-ups ($30 granted, $50 granted), then invoice consumes $60.
      # After backfill:
      # - TX1 -> TX3: $30 (TX1 fully consumed)
      # - TX2 -> TX3: $30 (TX2 partially consumed)

      it "creates consumption records following FIFO order" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "30")
          tx1 = wallet.wallet_transactions.inbound.first
        end

        travel_to(time_0 + 1.hour) do
          top_up_wallet(wallet, granted_credits: "50")
          tx2 = wallet.wallet_transactions.inbound.order(created_at: :desc).first
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 60)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx3 = wallet.wallet_transactions.outbound.settled.first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)
        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)

        consumptions = WalletTransactionConsumption.where(outbound_wallet_transaction_id: tx3.id)
          .order(:consumed_amount_cents)
        expect(consumptions.count).to eq(2)

        tx1_consumption = consumptions.find_by(inbound_wallet_transaction_id: tx1.id)
        tx2_consumption = consumptions.find_by(inbound_wallet_transaction_id: tx2.id)

        expect(tx1_consumption.consumed_amount_cents).to eq(3000)
        expect(tx2_consumption.consumed_amount_cents).to eq(3000)
      end
    end

    describe "multiple outbounds from same inbound" do
      # Customer tops up $100, then two billing periods consume $25 and $35.
      # After backfill:
      # - TX1 -> TX2: $25
      # - TX1 -> TX3: $35
      # - TX1.remaining_amount_cents = 4000

      it "creates separate consumption records for each outbound" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          tx1 = wallet.wallet_transactions.inbound.first
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx2 = wallet.wallet_transactions.outbound.settled.first

        travel_to(time_0 + 1.month + 5.days) do
          ingest_usage(subscription, 35)
        end

        travel_to(time_0 + 2.months) do
          perform_billing
        end

        tx3 = wallet.wallet_transactions.outbound.settled.order(created_at: :desc).first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)
        expect(tx1.reload.remaining_amount_cents).to eq(4000)

        consumptions = WalletTransactionConsumption.where(inbound_wallet_transaction_id: tx1.id)
        expect(consumptions.count).to eq(2)

        tx2_consumption = consumptions.find_by(outbound_wallet_transaction_id: tx2.id)
        tx3_consumption = consumptions.find_by(outbound_wallet_transaction_id: tx3.id)

        expect(tx2_consumption.consumed_amount_cents).to eq(2500)
        expect(tx3_consumption.consumed_amount_cents).to eq(3500)
      end
    end

    describe "priority-based consumption" do
      # Customer has: $20 granted (priority 1), $25 granted (priority 2 older),
      # $25 granted (priority 2 newer), $30 granted (priority 2 newest).
      # Invoice consumes $80. Consumption order:
      # TX1 (prio 1) -> TX2 (prio 2, oldest) -> TX3 (prio 2, newer) -> TX4 (prio 2, newest)

      it "consumes in order: granted before purchased, priority first, then FIFO" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        tx3 = nil
        tx4 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet

          transactions1 = top_up_wallet(wallet, granted_credits: "20")
          tx1 = transactions1.find(&:inbound?)
          tx1.update!(priority: 1)

          transactions2 = top_up_wallet(wallet, granted_credits: "25")
          tx2 = transactions2.find(&:inbound?)
          tx2.update!(priority: 2, created_at: 3.days.ago)

          transactions3 = top_up_wallet(wallet, granted_credits: "25")
          tx3 = transactions3.find(&:inbound?)
          tx3.update!(priority: 2, created_at: 1.day.ago)

          transactions4 = top_up_wallet(wallet, granted_credits: "30")
          tx4 = transactions4.find(&:inbound?)
          tx4.update!(priority: 2)

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 80)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx5 = wallet.wallet_transactions.outbound.settled.first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)

        consumptions = WalletTransactionConsumption.where(outbound_wallet_transaction_id: tx5.id)
        expect(consumptions.count).to eq(4)

        expect(consumptions.find_by(inbound_wallet_transaction_id: tx1.id).consumed_amount_cents).to eq(2000)
        expect(consumptions.find_by(inbound_wallet_transaction_id: tx2.id).consumed_amount_cents).to eq(2500)
        expect(consumptions.find_by(inbound_wallet_transaction_id: tx3.id).consumed_amount_cents).to eq(2500)
        expect(consumptions.find_by(inbound_wallet_transaction_id: tx4.id).consumed_amount_cents).to eq(1000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(0)
        expect(tx3.reload.remaining_amount_cents).to eq(0)
        expect(tx4.reload.remaining_amount_cents).to eq(2000)
      end
    end

    describe "granted before purchased ordering" do
      # Customer has $30 granted and $70 purchased. Invoice consumes $80.
      # Granted is consumed first, then purchased.

      it "consumes granted transactions before purchased" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "30")
          tx1 = wallet.wallet_transactions.inbound.where(transaction_status: :granted).first
        end

        travel_to(time_0 + 1.hour) do
          top_up_wallet(wallet, paid_credits: "70")
          tx2 = wallet.wallet_transactions.inbound.where(transaction_status: :purchased).first

          # Mark the credit invoice as paid so the purchased transaction becomes settled
          credit_invoice = customer.invoices.credit.sole
          update_invoice(credit_invoice, {payment_status: "succeeded"})
          perform_all_enqueued_jobs

          tx2.reload
          expect(tx2.status).to eq("settled")

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 80)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx3 = wallet.wallet_transactions.outbound.settled.where(transaction_status: :invoiced).first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)

        consumptions = WalletTransactionConsumption.where(outbound_wallet_transaction_id: tx3.id)
        expect(consumptions.count).to eq(2)

        tx1_consumption = consumptions.find_by(inbound_wallet_transaction_id: tx1.id)
        tx2_consumption = consumptions.find_by(inbound_wallet_transaction_id: tx2.id)

        expect(tx1_consumption.consumed_amount_cents).to eq(3000)
        expect(tx2_consumption.consumed_amount_cents).to eq(5000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)
      end
    end

    describe "idempotency" do
      it "does not create duplicate records when run twice" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 40)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)
        consumption_count = WalletTransactionConsumption.count
        remaining = wallet.wallet_transactions.inbound.first.reload.remaining_amount_cents

        # Run again - should not change anything since wallet is now traceable
        run_migration(dry_run: false)

        expect(WalletTransactionConsumption.count).to eq(consumption_count)
        expect(wallet.wallet_transactions.inbound.first.reload.remaining_amount_cents).to eq(remaining)
      end
    end

    describe "skips already traceable wallets" do
      it "does not process wallets that are already traceable" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        wallet.update_column(:traceable, true) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(dry_run: false)
        }.not_to change(WalletTransactionConsumption, :count)
      end
    end

    describe "skips terminated wallets by default" do
      it "does not process terminated wallets unless include_terminated is set" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        wallet.reload.update!(status: :terminated)

        expect {
          run_migration(dry_run: false)
        }.not_to change(WalletTransactionConsumption, :count)

        expect(wallet.reload.traceable).to eq(false)

        run_migration(dry_run: false, include_terminated: true)

        expect(wallet.reload.traceable).to eq(true)
      end
    end

    describe "wallet with no outbound transactions" do
      it "marks wallet as traceable and sets remaining_amount_cents" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        tx1 = wallet.wallet_transactions.inbound.first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)
        expect(tx1.reload.remaining_amount_cents).to eq(10000)
      end
    end

    describe "multiple customers processed independently" do
      let(:customer2) { create(:customer, organization:, billing_entity:) }

      it "processes each customer in separate transactions" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        subscription1 = nil
        subscription2 = nil

        travel_to(time_0) do
          # Customer 1 wallet
          wallet1 = create_non_traceable_wallet
          top_up_wallet(wallet1, granted_credits: "50")
          subscription1 = setup_subscription
        end

        travel_to(time_0) do
          # Customer 2 wallet
          params = {
            external_customer_id: customer2.external_id,
            rate_amount: "1",
            name: "Customer 2 Wallet",
            currency: "EUR",
            granted_credits: "0",
            invoice_requires_successful_payment: false
          }
          wallet2 = create_wallet(params, as: :model)
          top_up_wallet(wallet2, granted_credits: "80")

          create_subscription({
            external_customer_id: customer2.external_id,
            external_id: customer2.external_id,
            plan_code: plan.code
          })
          subscription2 = customer2.subscriptions.first
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription1, 20)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric.code,
            external_subscription_id: subscription2.external_id,
            properties: {billable_metric.field_name => 30}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        run_migration(dry_run: false)

        expect(wallet1.reload.traceable).to eq(true)
        expect(wallet2.reload.traceable).to eq(true)

        tx1 = wallet1.wallet_transactions.inbound.first
        tx2 = wallet2.wallet_transactions.inbound.first

        expect(tx1.reload.remaining_amount_cents).to eq(3000)
        expect(tx2.reload.remaining_amount_cents).to eq(5000)
      end
    end

    describe "multiple wallets for the same customer" do
      let(:billable_metric2) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
      let(:charge2) { create(:charge, plan:, billable_metric: billable_metric2, charge_model: "standard", properties: {"amount" => "1"}) }

      before { charge2 }

      def create_scoped_wallet(applies_to:, granted_credits: "0")
        params = {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Scoped Wallet",
          currency: "EUR",
          granted_credits:,
          invoice_requires_successful_payment: false,
          applies_to:
        }

        wallet = create_wallet(params, as: :model)
        wallet.update!(traceable: false)
        wallet
      end

      # Customer has two wallets scoped to different metrics:
      # - Wallet 1: $30 (applies to billable_metric)
      # - Wallet 2: $50 (applies to billable_metric2)
      # Invoice consumes $25 from each metric.
      # After backfill:
      # - Wallet 1: TX1 -> TX3: $25, remaining $5
      # - Wallet 2: TX2 -> TX4: $25, remaining $25
      # Both wallets marked traceable.

      it "backfills consumption records for each wallet independently" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        tx1 = nil
        tx2 = nil
        subscription = nil

        travel_to(time_0) do
          wallet1 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric.code]},
            granted_credits: "30"
          )
          tx1 = wallet1.wallet_transactions.inbound.first
        end

        travel_to(time_0 + 1.hour) do
          wallet2 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric2.code]},
            granted_credits: "50"
          )
          tx2 = wallet2.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric2.code,
            external_subscription_id: subscription.external_id,
            properties: {billable_metric2.field_name => 25}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        run_migration(dry_run: false)

        expect(wallet1.reload.traceable).to eq(true)
        expect(wallet2.reload.traceable).to eq(true)

        tx3 = wallet1.wallet_transactions.outbound.settled.first
        tx4 = wallet2.wallet_transactions.outbound.settled.first

        consumption1 = WalletTransactionConsumption.find_by(
          inbound_wallet_transaction_id: tx1.id,
          outbound_wallet_transaction_id: tx3.id
        )
        expect(consumption1.consumed_amount_cents).to eq(2500)

        consumption2 = WalletTransactionConsumption.find_by(
          inbound_wallet_transaction_id: tx2.id,
          outbound_wallet_transaction_id: tx4.id
        )
        expect(consumption2.consumed_amount_cents).to eq(2500)

        expect(tx1.reload.remaining_amount_cents).to eq(500)
        expect(tx2.reload.remaining_amount_cents).to eq(2500)
      end

      it "only migrates non-traceable wallets, leaving already-traceable ones untouched" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        subscription = nil

        travel_to(time_0) do
          wallet1 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric.code]},
            granted_credits: "30"
          )
          # Mark wallet1 as already traceable (simulating it was already migrated)
          wallet1.update_column(:traceable, true) # rubocop:disable Rails/SkipsModelValidations
          wallet1.wallet_transactions.inbound.each do |tx|
            tx.update_column(:remaining_amount_cents, tx.amount_cents) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        travel_to(time_0 + 1.hour) do
          wallet2 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric2.code]},
            granted_credits: "50"
          )

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric2.code,
            external_subscription_id: subscription.external_id,
            properties: {billable_metric2.field_name => 25}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        # wallet1 is traceable, so billing already created consumption records for it
        tx3 = wallet1.wallet_transactions.outbound.settled.first
        consumption_count_before = WalletTransactionConsumption.where(outbound_wallet_transaction_id: tx3.id).count
        expect(consumption_count_before).to eq(1)

        run_migration(dry_run: false)

        # wallet1 was already traceable — migration did not create additional consumption records
        expect(WalletTransactionConsumption.where(outbound_wallet_transaction_id: tx3.id).count).to eq(consumption_count_before)

        # wallet2 was non-traceable — should now be migrated
        expect(wallet2.reload.traceable).to eq(true)
        tx4 = wallet2.wallet_transactions.outbound.settled.first
        consumption = WalletTransactionConsumption.find_by(outbound_wallet_transaction_id: tx4.id)
        expect(consumption.consumed_amount_cents).to eq(2500)
      end

      # Customer has three wallets:
      # - Wallet 1: active, non-traceable, $30 (applies to billable_metric) — should be migrated
      # - Wallet 2: terminated, non-traceable, $50 (applies to billable_metric2) — should be migrated (include_terminated)
      # - Wallet 3: active, already traceable, $20 (applies to billable_metric) — should be skipped

      it "migrates active and terminated non-traceable wallets, skips already-traceable ones" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        tx1 = nil
        tx2 = nil
        subscription = nil

        travel_to(time_0) do
          # Wallet 1: active, non-traceable
          wallet1 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric.code]},
            granted_credits: "30"
          )
          tx1 = wallet1.wallet_transactions.inbound.first
        end

        travel_to(time_0 + 1.hour) do
          # Wallet 2: will be terminated, non-traceable
          wallet2 = create_scoped_wallet(
            applies_to: {billable_metric_codes: [billable_metric2.code]},
            granted_credits: "50"
          )
          tx2 = wallet2.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 20)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric2.code,
            external_subscription_id: subscription.external_id,
            properties: {billable_metric2.field_name => 15}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        # Terminate wallet2 after billing
        wallet2.reload.update!(status: :terminated)

        # Wallet 3: active, already traceable — created after billing so no outbound
        wallet3 = create_scoped_wallet(
          applies_to: {billable_metric_codes: [billable_metric.code]},
          granted_credits: "20"
        )
        wallet3.update_column(:traceable, true) # rubocop:disable Rails/SkipsModelValidations
        wallet3.wallet_transactions.inbound.each do |tx|
          tx.update_column(:remaining_amount_cents, tx.amount_cents) # rubocop:disable Rails/SkipsModelValidations
        end

        WalletTransactionConsumption.count

        run_migration(dry_run: false, include_terminated: true)

        # Wallet 1: active, non-traceable -> migrated
        expect(wallet1.reload.traceable).to eq(true)
        expect(tx1.reload.remaining_amount_cents).to eq(1000)
        tx3 = wallet1.wallet_transactions.outbound.settled.first
        expect(WalletTransactionConsumption.find_by(
          inbound_wallet_transaction_id: tx1.id,
          outbound_wallet_transaction_id: tx3.id
        ).consumed_amount_cents).to eq(2000)

        # Wallet 2: terminated, non-traceable -> migrated
        expect(wallet2.reload.traceable).to eq(true)
        expect(wallet2.status).to eq("terminated")
        expect(tx2.reload.remaining_amount_cents).to eq(3500)
        tx4 = wallet2.wallet_transactions.outbound.settled.first
        expect(WalletTransactionConsumption.find_by(
          inbound_wallet_transaction_id: tx2.id,
          outbound_wallet_transaction_id: tx4.id
        ).consumed_amount_cents).to eq(1500)

        # Wallet 3: already traceable -> no new consumption records
        wallet3_consumptions = WalletTransactionConsumption.where(
          inbound_wallet_transaction_id: wallet3.wallet_transactions.inbound.pluck(:id)
        )
        expect(wallet3_consumptions.count).to eq(0)
      end
    end

    describe "customer rollback when one wallet fails" do
      let(:billable_metric2) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
      let(:charge2) { create(:charge, plan:, billable_metric:, charge_model: "standard", properties: {"amount" => "1"}) }

      before { charge2 }

      # Customer has two wallets:
      # - Wallet 1: migratable ($50 inbound, $20 outbound)
      # - Wallet 2: NOT migratable (inbound amount corrupted so outbound can't be consumed)
      #
      # Since all wallets for a customer are processed in a single transaction,
      # the failure on wallet2 should roll back wallet1's changes too.

      it "rolls back all wallets for the customer when one wallet fails" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        subscription = nil

        travel_to(time_0) do
          wallet1 = create_non_traceable_wallet
          top_up_wallet(wallet1, granted_credits: "50")

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 20)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        # Create wallet2 with an inconsistent state: outbound > inbound
        wallet2 = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        inbound = create(:wallet_transaction, wallet: wallet2, organization:,
          transaction_type: :inbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :granted, remaining_amount_cents: nil)
        create(:wallet_transaction, wallet: wallet2, organization:,
          transaction_type: :outbound, status: :settled, amount: "50.00", credit_amount: "50.00",
          transaction_status: :invoiced, created_at: inbound.created_at + 1.hour)

        run_migration(dry_run: false)

        # Neither wallet should be marked traceable
        expect(wallet1.reload.traceable).to eq(false)
        expect(wallet2.reload.traceable).to eq(false)

        # No consumption records created for either wallet
        wallet1_consumptions = WalletTransactionConsumption.where(
          inbound_wallet_transaction_id: wallet1.wallet_transactions.inbound.pluck(:id)
        )
        expect(wallet1_consumptions.count).to eq(0)

        wallet2_consumptions = WalletTransactionConsumption.where(
          inbound_wallet_transaction_id: wallet2.wallet_transactions.inbound.pluck(:id)
        )
        expect(wallet2_consumptions.count).to eq(0)
      end
    end

    describe "backfill error reporting" do
      it "reports errors in the summary output" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        inbound = create(:wallet_transaction, wallet:, organization:,
          transaction_type: :inbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :granted, remaining_amount_cents: nil)
        create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "50.00", credit_amount: "50.00",
          transaction_status: :invoiced, created_at: inbound.created_at + 1.hour)

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("insufficient inbound to consume"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
        expect(inbound.reload.remaining_amount_cents).to be_nil
        expect(WalletTransactionConsumption.where(inbound_wallet_transaction_id: inbound.id).count).to eq(0)
      end

      it "rejects wallet with negative balance" do
        wallet = create_non_traceable_wallet
        Wallet.where(id: wallet.id).update_all(balance_cents: -500, credits_balance: -5) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("Negative wallet balance"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
      end

      it "rejects wallet with negative amount_cents on inbound transaction" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00",
          balance_cents: 0, credits_balance: 0)
        inbound = create(:wallet_transaction, wallet:, organization:,
          transaction_type: :inbound, status: :settled, amount: "-10.00", credit_amount: "-10.00",
          transaction_status: :granted, remaining_amount_cents: nil)

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("Negative amount_cents on inbound"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
        expect(inbound.reload.remaining_amount_cents).to be_nil
      end

      it "rejects wallet with negative amount_cents on outbound transaction" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00",
          balance_cents: 0, credits_balance: 0)
        outbound = create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "-10.00", credit_amount: "-10.00",
          transaction_status: :invoiced)

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("Negative amount_cents on outbound"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
        expect(WalletTransactionConsumption.where(outbound_wallet_transaction_id: outbound.id).count).to eq(0)
      end

      it "rejects wallet with outbound but no inbound transactions" do
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        outbound = create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :invoiced)

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("missing transaction history"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
        expect(WalletTransactionConsumption.where(outbound_wallet_transaction_id: outbound.id).count).to eq(0)
      end

      it "rejects wallet with balance drift" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        inbound = wallet.wallet_transactions.inbound.first
        Wallet.where(id: wallet.id).update_all(balance_cents: 5000, credits_balance: 50) # rubocop:disable Rails/SkipsModelValidations

        expect {
          run_migration(dry_run: false, silent: false)
        }.to output(
          a_string_including("Errors: 1")
            .and(a_string_including("Balance drift"))
        ).to_stdout
        expect(wallet.reload.traceable).to eq(false)
        expect(inbound.reload.remaining_amount_cents).to be_nil
        expect(WalletTransactionConsumption.where(inbound_wallet_transaction_id: inbound.id).count).to eq(0)
      end

      it "continues processing other customers when one customer errors" do
        other_customer = create(:customer, organization:, billing_entity:)

        # Healthy wallet for other_customer
        healthy_wallet_params = {
          external_customer_id: other_customer.external_id,
          rate_amount: "1",
          name: "Healthy Wallet",
          currency: "EUR",
          granted_credits: "0",
          invoice_requires_successful_payment: false
        }
        api_call { post_with_token(organization, "/api/v1/wallets", {wallet: healthy_wallet_params}) }
        healthy_wallet = Wallet.find(json[:wallet][:lago_id])
        api_call do
          post_with_token(organization, "/api/v1/wallet_transactions", {
            wallet_transaction: {wallet_id: healthy_wallet.id, granted_credits: "30"}
          })
        end

        # Broken wallet for customer (outbound > inbound)
        broken_wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        inbound = create(:wallet_transaction, wallet: broken_wallet, organization:,
          transaction_type: :inbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :granted)
        create(:wallet_transaction, wallet: broken_wallet, organization:,
          transaction_type: :outbound, status: :settled, amount: "50.00", credit_amount: "50.00",
          transaction_status: :invoiced, created_at: inbound.created_at + 1.hour)

        run_migration(dry_run: false)

        expect(healthy_wallet.reload.traceable).to eq(true)
        expect(broken_wallet.reload.traceable).to eq(false)
      end
    end

    describe "CSV export on backfill errors" do
      it "exports errors to CSV when output_file is set" do
        # Create wallet with inconsistent state: outbound > inbound
        wallet = create(:wallet, customer:, organization:, traceable: false, currency: "EUR", rate_amount: "1.00")
        inbound = create(:wallet_transaction, wallet:, organization:,
          transaction_type: :inbound, status: :settled, amount: "10.00", credit_amount: "10.00",
          transaction_status: :granted, remaining_amount_cents: nil)
        create(:wallet_transaction, wallet:, organization:,
          transaction_type: :outbound, status: :settled, amount: "50.00", credit_amount: "50.00",
          transaction_status: :invoiced, created_at: inbound.created_at + 1.hour)

        Tempfile.create(["backfill_errors", ".csv"]) do |tmpfile|
          env_vars = {
            "ORGANIZATION_ID" => organization.id,
            "BATCH_SIZE" => "100",
            "ERROR_DISPLAY_LIMIT" => "50",
            "DRY_RUN" => "false",
            "ERROR_LOG_FILE" => tmpfile.path
          }
          env_vars.each { |k, v| ENV[k] = v }
          task.reenable
          expect { task.invoke }.to output(anything).to_stdout

          rows = CSV.read(tmpfile.path, headers: true)
          expect(rows.headers).to eq(%w[wallet_id customer_id customer_name organization_id organization_name created_at issues])
          expect(rows.size).to eq(1)
          row = rows.first
          expect(row["wallet_id"]).to eq(wallet.id)
          expect(row["customer_id"]).to eq(customer.id)
          expect(row["customer_name"]).to eq(customer.name)
          expect(row["organization_id"]).to eq(organization.id)
          expect(row["organization_name"]).to eq(organization.name)
          expect(row["created_at"]).to eq(wallet.created_at.to_date.to_s)
          expect(row["issues"]).to include("insufficient inbound to consume")
        ensure
          env_vars&.each_key { |k| ENV.delete(k) }
        end
      end
    end

    describe "non-integer wallet rate" do
      it "correctly tracks consumption with non-integer rate_amount" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet(rate_amount: "0.5")
          top_up_wallet(wallet, granted_credits: "100")
          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          # With rate 0.5, 100 credits = 50 EUR. Usage of 30 EUR = 60 credits consumed.
          ingest_usage(subscription, 30)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx1 = wallet.wallet_transactions.inbound.settled.first
        tx2 = wallet.wallet_transactions.outbound.settled.first

        run_migration(dry_run: false)

        expect(wallet.reload.traceable).to eq(true)

        consumption = WalletTransactionConsumption.find_by(
          inbound_wallet_transaction_id: tx1.id,
          outbound_wallet_transaction_id: tx2.id
        )
        expect(consumption).to be_present
        expect(consumption.consumed_amount_cents).to eq(3000)
        expect(tx1.reload.remaining_amount_cents).to eq(2000)
      end
    end
  end

  describe "invalid CURSOR" do
    it "raises an error for non-UUID values" do
      ENV["CURSOR"] = "not-a-uuid"
      task.reenable

      expect { task.invoke }.to raise_error(RuntimeError, /Invalid CURSOR format: not-a-uuid/)
    ensure
      ENV.delete("CURSOR")
    end

    it "raises an error for pipe-separated values" do
      ENV["CURSOR"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa|bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
      task.reenable

      expect { task.invoke }.to raise_error(RuntimeError, /Invalid CURSOR format/)
    ensure
      ENV.delete("CURSOR")
    end
  end

  describe "invalid ERROR_LOG_FILE" do
    it "raises an error at startup when the file path is not writable" do
      ENV["ERROR_LOG_FILE"] = "/nonexistent/directory/errors.csv"
      task.reenable

      expect { task.invoke }.to raise_error(RuntimeError, /Cannot write to error log file/)
    ensure
      ENV.delete("ERROR_LOG_FILE")
    end
  end

  describe "invalid numeric ENV vars" do
    %w[LIMIT BATCH_SIZE ERROR_DISPLAY_LIMIT].each do |var|
      it "raises an error when #{var} is not numeric" do
        ENV[var] = "abc"
        task.reenable

        expect { task.invoke }.to raise_error(RuntimeError, /#{var} must be a positive integer, got: abc/)
      ensure
        ENV.delete(var)
      end

      it "raises an error when #{var} is zero" do
        ENV[var] = "0"
        task.reenable

        expect { task.invoke }.to raise_error(RuntimeError, /#{var} must be a positive integer, got: 0/)
      ensure
        ENV.delete(var)
      end

      it "raises an error when #{var} is negative" do
        ENV[var] = "-1"
        task.reenable

        expect { task.invoke }.to raise_error(RuntimeError, /#{var} must be a positive integer, got: -1/)
      ensure
        ENV.delete(var)
      end
    end

    it "raises an error when THREAD_COUNT is not numeric" do
      ENV["THREAD_COUNT"] = "abc"
      task.reenable

      expect { task.invoke }.to raise_error(RuntimeError, /THREAD_COUNT must be a non-negative integer, got: abc/)
    ensure
      ENV.delete("THREAD_COUNT")
    end

    it "raises an error when THREAD_COUNT is negative" do
      ENV["THREAD_COUNT"] = "-1"
      task.reenable

      expect { task.invoke }.to raise_error(RuntimeError, /THREAD_COUNT must be a non-negative integer, got: -1/)
    ensure
      ENV.delete("THREAD_COUNT")
    end
  end
end
