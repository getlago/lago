# frozen_string_literal: true

namespace :migrations do
  desc "Backfill billing_entity_id on existing wallet transactions"
  task backfill_wallet_transactions_billing_entity: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    # Every wallet transaction resolves to a billing entity (customers.billing_entity_id
    # is NOT NULL), so a plain index-backed count of NULL rows is an accurate progress signal.
    count_sql = "SELECT COUNT(*) FROM wallet_transactions WHERE billing_entity_id IS NULL"

    puts "##################################\nStarting wallet transactions billing entity backfill"
    puts "\n#### Checking for resources to fill ####"

    count = ActiveRecord::Base.connection.select_value(count_sql).to_i

    if count > 0
      pp "  -> #{count} wallet transactions to backfill"
      puts "\n#### Enqueue job in the low_priority queue ####"
      pp "- Enqueuing DatabaseMigrations::BackfillWalletTransactionsBillingEntityJob"
      pp "- Make sure a Sidekiq worker is draining the low_priority queue"
      DatabaseMigrations::BackfillWalletTransactionsBillingEntityJob.perform_later
    else
      pp "  -> Nothing to do"
    end

    stalled_checks = 0

    while count > 0
      Kernel.sleep 5
      puts "\n#### Checking status ####"

      previous_count = count
      count = ActiveRecord::Base.connection.select_value(count_sql).to_i

      if count < previous_count
        stalled_checks = 0
        pp "  -> #{count} remaining"
      elsif count.zero?
        pp "  -> Done"
      else
        stalled_checks += 1
        pp "  -> #{count} remaining, no progress (#{stalled_checks})"
        if stalled_checks >= 10
          abort "No progress after #{stalled_checks} checks. Is a Sidekiq worker draining the low_priority queue?"
        end
      end
    end

    puts "\n#### All good! ####"
  end
end
