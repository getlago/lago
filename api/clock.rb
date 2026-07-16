# frozen_string_literal: true

require "clockwork"
require "./config/boot"
require "./config/environment"

module Clockwork
  handler do |job, time|
    puts "Running #{job} at #{time}" # rubocop:disable Rails/Output
  end

  error_handler do |error|
    Rails.logger.error(error.message)
    Rails.logger.error(error.backtrace.join("\n"))

    Sentry.capture_exception(error)
  end

  # NOTE: All clocks run every hour to take customer timezones into account

  every(5.minutes, "schedule:activate_subscriptions") do
    Clock::ActivateSubscriptionsJob
      .set(sentry: {"slug" => "lago_activate_subscriptions", "cron" => "*/5 * * * *"})
      .perform_later
  end

  every(5.minutes, "schedule:refresh_draft_invoices") do
    Clock::RefreshDraftInvoicesJob
      .set(sentry: {"slug" => "lago_refresh_draft_invoices", "cron" => "*/5 * * * *"})
      .perform_later
  end

  subscription_activity_processing_interval = ENV["LAGO_SUBSCRIPTION_ACTIVITY_PROCESSING_INTERVAL_SECONDS"].presence || 1.minute
  every(subscription_activity_processing_interval.to_i.seconds, "schedule:process_subscription_activity") do
    Clock::ProcessAllSubscriptionActivitiesJob
      .set(sentry: {"slug" => "lago_process_subscription_activity", "cron" => "#{subscription_activity_processing_interval} interval"})
      .perform_later
  end

  if Utils::DedicatedWorkerConfig.any?
    every(Utils::DedicatedWorkerConfig.refresh_interval, "schedule:process_dedicated_orgs_subscription_activities") do
      Clock::ProcessDedicatedOrgsSubscriptionActivitiesJob.perform_later
    end
  end

  lifetime_usage_refresh_interval = ENV["LAGO_LIFETIME_USAGE_REFRESH_INTERVAL_SECONDS"].presence || 5.minutes
  every(lifetime_usage_refresh_interval.to_i.seconds, "schedule:refresh_lifetime_usages") do
    unless ENV["LAGO_DISABLE_LIFETIME_USAGE_REFRESH"] == "true"
      Clock::RefreshLifetimeUsagesJob
        .set(sentry: {"slug" => "lago_refresh_lifetime_usages", "cron" => "#{lifetime_usage_refresh_interval} interval"})
        .perform_later
    end
  end

  if ENV["LAGO_MEMCACHE_SERVERS"].present? || ENV["LAGO_REDIS_CACHE_URL"].present?
    unless ENV["LAGO_DISABLE_WALLET_REFRESH"] == "true"
      wallet_refresh_interval = ENV["LAGO_WALLET_ONGOING_BALANCE_REFRESH_INTERVAL_SECONDS"].presence || 5.minutes

      every(wallet_refresh_interval.to_i.seconds, "schedule:refresh_wallets_ongoing_balance") do
        Clock::RefreshWalletsOngoingBalanceJob
          .set(sentry: {"slug" => "lago_refresh_wallets_ongoing_balance", "cron" => "#{wallet_refresh_interval} interval"})
          .perform_later
      end

      if Utils::DedicatedWorkerConfig.any?
        every(Utils::DedicatedWorkerConfig.refresh_interval, "schedule:refresh_dedicated_org_wallets") do
          Clock::RefreshDedicatedOrgWalletsOngoingBalanceJob.perform_later
        end
      end
    end
  end

  every(1.hour, "schedule:terminate_ended_subscriptions", at: "*:05") do
    Clock::TerminateEndedSubscriptionsJob
      .set(sentry: {"slug" => "lago_terminate_ended_subscriptions", "cron" => "5 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:bill_customers", at: "*:10") do
    Clock::SubscriptionsBillerJob
      .set(sentry: {"slug" => "lago_bill_customers", "cron" => "10 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:api_keys_track_usage", at: "*:15") do
    Clock::ApiKeys::TrackUsageJob
      .set(sentry: {"slug" => "lago_api_keys_track_usage", "cron" => "15 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:expire_incomplete_subscriptions", at: "*:20") do
    Clock::ExpireIncompleteSubscriptionsJob
      .set(sentry: {"slug" => "lago_expire_incomplete_subscriptions", "cron" => "20 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:retry_generating_subscription_invoices", at: "*:30") do
    Clock::RetryGeneratingSubscriptionInvoicesJob
      .set(sentry: {"slug" => "lago_retry_invoices", "cron" => "30 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:finalize_invoices", at: "*:20") do
    Clock::FinalizeInvoicesJob
      .set(sentry: {"slug" => "lago_finalize_invoices", "cron" => "20 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:mark_invoices_as_payment_overdue", at: "*:25") do
    Clock::MarkInvoicesAsPaymentOverdueJob
      .set(sentry: {"slug" => "lago_mark_invoices_as_payment_overdue", "cron" => "25 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:terminate_coupons", at: "*:30") do
    Clock::TerminateCouponsJob
      .set(sentry: {"slug" => "lago_terminate_coupons", "cron" => "30 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:bill_ended_trial_subscriptions", at: "*:35") do
    Clock::FreeTrialSubscriptionsBillerJob
      .set(sentry: {"slug" => "lago_bill_ended_trial_subscriptions", "cron" => "35 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:terminate_wallets", at: "*:45") do
    Clock::TerminateWalletsJob
      .set(sentry: {"slug" => "lago_terminate_wallets", "cron" => "45 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:termination_alert", at: "*:50") do
    Clock::SubscriptionsToBeTerminatedJob
      .set(sentry: {"slug" => "lago_termination_alert", "cron" => "50 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:terminate_expired_wallet_transaction_rules", at: "*:50") do
    Clock::TerminateRecurringTransactionRulesJob
      .set(sentry: {"slug" => "lago_terminate_expired_wallet_transaction_rules", "cron" => "50 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:top_up_wallet_interval_credits", at: "*:55") do
    Clock::CreateIntervalWalletTransactionsJob
      .set(sentry: {"slug" => "lago_top_up_wallet_interval_credits", "cron" => "55 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:expire_order_forms", at: "*:40") do
    Clock::ExpireOrderFormsJob
      .set(sentry: {"slug" => "lago_expire_order_forms", "cron" => "40 */1 * * *"})
      .perform_later
  end

  every(1.day, "schedule:clean_webhooks", at: "01:00") do
    Clock::WebhooksCleanupJob
      .set(sentry: {"slug" => "lago_clean_webhooks", "cron" => "0 1 * * *"})
      .perform_later
  end

  every(1.day, "schedule:clean_inbound_webhooks", at: "01:10") do
    Clock::InboundWebhooksCleanupJob
      .set(sentry: {"slug" => "lago_clean_inbound_webhooks", "cron" => "5 1 * * *"})
      .perform_later
  end

  unless ActiveModel::Type::Boolean.new.cast(ENV["LAGO_DISABLE_EVENTS_VALIDATION"])
    every(1.hour, "schedule:post_validate_events", at: "*:05") do
      Clock::EventsValidationJob
        .set(sentry: {"slug" => "lago_post_validate_events", "cron" => "5 */1 * * *"})
        .perform_later
    rescue => e
      Sentry.capture_exception(e)
    end
  end

  every(1.hour, "schedule:compute_daily_usage", at: "*:15") do
    Clock::ComputeAllDailyUsagesJob
      .set(sentry: {"slug" => "lago_compute_daily_usage", "cron" => "15 */1 * * *"})
      .perform_later
  end

  every(1.hour, "schedule:process_dunning_campaigns", at: "*:45") do
    Clock::ProcessDunningCampaignsJob
      .set(sentry: {"slug" => "lago_process_dunning_campaigns", "cron" => "45 */1 * * *"})
      .perform_later
  end

  every(15.minutes, "schedule:retry_failed_invoices") do
    Clock::RetryFailedInvoicesJob
      .set(sentry: {"slug" => "lago_retry_failed_invoices", "cron" => "*/15 * * * *"})
      .perform_later
  end

  every(15.minutes, "schedule:retry_inbound_webhooks") do
    Clock::InboundWebhooksRetryJob
      .set(sentry: {"slug" => "lago_retry_inbound_webhooks", "cron" => "*/15 * * * *"})
      .perform_later
  end

  # NOTE: Enable wallets and lifetime usage refresh from the events-processor
  if ENV["LAGO_REDIS_STORE_URL"].present? && ENV["LAGO_CLICKHOUSE_ENABLED"].present?
    every(10.seconds, "schedule:refresh_flagged_subscriptions") do
      Clock::ConsumeSubscriptionRefreshedQueueJob
        .set(sentry: {"slug" => "lago_refresh_flagged_subscriptions"})
        .perform_later
    end
  end
end
