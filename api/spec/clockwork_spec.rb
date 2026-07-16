# frozen_string_literal: true

require "rails_helper"

describe Clockwork do
  after { Clockwork::Test.clear! }

  let(:clock_file) { Rails.root.join("clock.rb") }

  describe "schedule:terminate_expired_wallet_transaction_rules" do
    let(:job) { "schedule:terminate_expired_wallet_transaction_rules" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:50:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:50:00") }

    it "enqueues a terminate expired wallet transaction rules job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::TerminateRecurringTransactionRulesJob).to have_been_enqueued
    end
  end

  describe "schedule:bill_customers" do
    let(:job) { "schedule:bill_customers" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:01:00") }

    it "enqueue a subscription biller job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::SubscriptionsBillerJob).to have_been_enqueued
    end
  end

  describe "schedule:activate_subscriptions" do
    let(:job) { "schedule:activate_subscriptions" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 00:31:00") }

    it "enqueue a activate subscriptions job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(6)

      Clockwork::Test.block_for(job).call
      expect(Clock::ActivateSubscriptionsJob).to have_been_enqueued
    end
  end

  describe "schedule:process_subscription_activity" do
    let(:job) { "schedule:process_subscription_activity" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 00:31:00") }

    it "enqueue a process subscription activity job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(30)

      Clockwork::Test.block_for(job).call
      expect(Clock::ProcessAllSubscriptionActivitiesJob).to have_been_enqueued.once
    end

    context "with a custom refresh interval configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("LAGO_SUBSCRIPTION_ACTIVITY_PROCESSING_INTERVAL_SECONDS").and_return("150")
      end

      it 'uses the ENV["LAGO_SUBSCRIPTION_ACTIVITY_PROCESSING_INTERVAL_SECONDS"] to set a custom period' do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).to be_ran_job(job)
        expect(Clockwork::Test.times_run(job)).to eq(12)

        Clockwork::Test.block_for(job).call
        expect(Clock::ProcessAllSubscriptionActivitiesJob).to have_been_enqueued.once

        expect(ENV).to have_received(:[]).with("LAGO_SUBSCRIPTION_ACTIVITY_PROCESSING_INTERVAL_SECONDS")
      end
    end
  end

  describe "schedule:post_validate_events" do
    let(:job) { "schedule:post_validate_events" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 01:00:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 03:00:00") }

    it "enqueue a activate subscriptions job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(2)

      Clockwork::Test.block_for(job).call
      expect(Clock::EventsValidationJob).to have_been_enqueued
    end
  end

  describe "schedule:refresh_lifetime_usages" do
    let(:job) { "schedule:refresh_lifetime_usages" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 00:31:00") }

    it "enqueue a refresh lifetime usages job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(6)

      Clockwork::Test.block_for(job).call
      expect(Clock::RefreshLifetimeUsagesJob).to have_been_enqueued
    end

    context "with a custom refresh interval configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("LAGO_LIFETIME_USAGE_REFRESH_INTERVAL_SECONDS").and_return("150")
      end

      it 'uses the ENV["LAGO_LIFETIME_USAGE_REFRESH_INTERVAL_SECONDS"] to set a custom period' do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).to be_ran_job(job)
        expect(Clockwork::Test.times_run(job)).to eq(12)

        Clockwork::Test.block_for(job).call
        expect(Clock::RefreshLifetimeUsagesJob).to have_been_enqueued

        expect(ENV).to have_received(:[]).with("LAGO_LIFETIME_USAGE_REFRESH_INTERVAL_SECONDS")
      end
    end
  end

  describe "schedule:retry_generating_subscription_invoices" do
    let(:job) { "schedule:retry_generating_subscription_invoices" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:01:00") }

    it "enqueues a Clock::RetryGeneratingSubscriptionInvoiceJob" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::RetryGeneratingSubscriptionInvoicesJob).to have_been_enqueued
    end
  end

  describe "schedule:compute_daily_usage" do
    let(:job) { "schedule:compute_daily_usage" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:01:00") }

    it "enqueue a activate subscriptions job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::ComputeAllDailyUsagesJob).to have_been_enqueued
    end
  end

  describe "schedule:process_dunning_campaigns" do
    let(:job) { "schedule:process_dunning_campaigns" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:01:00") }

    it "enqueue a process dunning campaigns job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::ProcessDunningCampaignsJob).to have_been_enqueued
    end
  end

  describe "schedule:expire_order_forms" do
    let(:job) { "schedule:expire_order_forms" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:30:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 01:30:00") }

    it "enqueues an expire order forms job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.minute
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::ExpireOrderFormsJob).to have_been_enqueued
    end
  end

  describe "schedule:clean_inbound_webhooks" do
    let(:job) { "schedule:clean_inbound_webhooks" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("2 Apr 2022 00:00:00") }

    it "enqueue a clean inbound webhooks job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.minute
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::InboundWebhooksCleanupJob).to have_been_enqueued
    end
  end

  describe "schedule:retry_inbound_webhooks" do
    let(:job) { "schedule:retry_inbound_webhooks" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:05:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 00:20:00") }

    it "enqueue a retry inbound webhooks job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.minute
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(1)

      Clockwork::Test.block_for(job).call
      expect(Clock::InboundWebhooksRetryJob).to have_been_enqueued
    end
  end

  describe "schedule:refresh_flagged_subscriptions" do
    let(:job) { "schedule:refresh_flagged_subscriptions" }
    let(:start_time) { Time.zone.parse("2025-03-27T00:05:00") }
    let(:end_time) { Time.zone.parse("2025-03-27T00:06:00") }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("LAGO_KAFKA_BOOTSTRAP_SERVERS").and_return("redpanda:9092")
      allow(ENV).to receive(:[]).with("LAGO_REDIS_STORE_URL").and_return("redis:6379")
      allow(ENV).to receive(:[]).with("LAGO_CLICKHOUSE_ENABLED").and_return("true")
    end

    it "enqueue a refresh flagged subscriptions job every 10 seconds" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(6)

      Clockwork::Test.block_for(job).call
      expect(Clock::ConsumeSubscriptionRefreshedQueueJob).to have_been_enqueued
    end
  end

  describe "schedule:process_dedicated_orgs_subscription_activities" do
    let(:job) { "schedule:process_dedicated_orgs_subscription_activities" }
    let(:start_time) { Time.zone.parse("2025-03-27T00:05:00") }
    let(:end_time) { Time.zone.parse("2025-03-27T00:06:00") }

    before do
      allow(ENV).to receive(:[]).and_call_original
      stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", ["org-1"])
    end

    it "enqueues a process dedicated orgs subscription activities job every 5 seconds" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(12)

      Clockwork::Test.block_for(job).call
      expect(Clock::ProcessDedicatedOrgsSubscriptionActivitiesJob).to have_been_enqueued
    end

    context "with a custom interval configured" do
      before do
        allow(ENV).to receive(:[]).with("LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS").and_return("10")
      end

      it 'uses the ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"] to set a custom period' do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).to be_ran_job(job)
        expect(Clockwork::Test.times_run(job)).to eq(6)

        Clockwork::Test.block_for(job).call
        expect(Clock::ProcessDedicatedOrgsSubscriptionActivitiesJob).to have_been_enqueued
      end
    end

    context "when the dedicated org list is empty" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", []) }

      it "does not register the schedule" do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).not_to be_ran_job(job)
      end
    end
  end

  describe "schedule:refresh_wallets_ongoing_balance" do
    let(:job) { "schedule:refresh_wallets_ongoing_balance" }
    let(:start_time) { Time.zone.parse("1 Apr 2022 00:01:00") }
    let(:end_time) { Time.zone.parse("1 Apr 2022 00:31:00") }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("LAGO_REDIS_CACHE_URL").and_return("redis:6379")
      allow(ENV).to receive(:[]).with("LAGO_DISABLE_WALLET_REFRESH").and_return(nil)
    end

    it "enqueue a refresh wallets ongoing balance job" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(6)

      Clockwork::Test.block_for(job).call
      expect(Clock::RefreshWalletsOngoingBalanceJob).to have_been_enqueued
    end

    context "with a custom refresh interval configured" do
      before do
        allow(ENV).to receive(:[]).with("LAGO_WALLET_ONGOING_BALANCE_REFRESH_INTERVAL_SECONDS").and_return("150")
      end

      it 'uses the ENV["LAGO_WALLET_ONGOING_BALANCE_REFRESH_INTERVAL_SECONDS"] to set a custom period' do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).to be_ran_job(job)
        expect(Clockwork::Test.times_run(job)).to eq(12)

        Clockwork::Test.block_for(job).call
        expect(Clock::RefreshWalletsOngoingBalanceJob).to have_been_enqueued

        expect(ENV).to have_received(:[]).with("LAGO_WALLET_ONGOING_BALANCE_REFRESH_INTERVAL_SECONDS")
      end
    end

    context "when wallet refresh is disabled" do
      before { allow(ENV).to receive(:[]).with("LAGO_DISABLE_WALLET_REFRESH").and_return("true") }

      it "does not register the schedule" do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).not_to be_ran_job(job)
      end
    end
  end

  describe "schedule:refresh_dedicated_org_wallets" do
    let(:job) { "schedule:refresh_dedicated_org_wallets" }
    let(:start_time) { Time.zone.parse("2025-03-27T00:05:00") }
    let(:end_time) { Time.zone.parse("2025-03-27T00:06:00") }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("LAGO_REDIS_CACHE_URL").and_return("redis:6379")
      allow(ENV).to receive(:[]).with("LAGO_DISABLE_WALLET_REFRESH").and_return(nil)
      stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", ["org-1"])
    end

    it "enqueue a refresh dedicated org wallets job every 5 seconds" do
      Clockwork::Test.run(
        file: clock_file,
        start_time:,
        end_time:,
        tick_speed: 1.second
      )

      expect(Clockwork::Test).to be_ran_job(job)
      expect(Clockwork::Test.times_run(job)).to eq(12)

      Clockwork::Test.block_for(job).call
      expect(Clock::RefreshDedicatedOrgWalletsOngoingBalanceJob).to have_been_enqueued
    end

    context "with a custom interval configured" do
      before do
        allow(ENV).to receive(:[]).with("LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS").and_return("10")
      end

      it 'uses the ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"] to set a custom period' do
        Clockwork::Test.run(
          file: clock_file,
          start_time:,
          end_time:,
          tick_speed: 1.second
        )

        expect(Clockwork::Test).to be_ran_job(job)
        expect(Clockwork::Test.times_run(job)).to eq(6)

        Clockwork::Test.block_for(job).call
        expect(Clock::RefreshDedicatedOrgWalletsOngoingBalanceJob).to have_been_enqueued
      end
    end
  end
end
