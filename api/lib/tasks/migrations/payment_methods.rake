# frozen_string_literal: true

namespace :migrations do
  desc "Backfill payment methods from existing Stripe provider customers"
  task backfill_stripe_payment_methods: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    count_sql = <<~SQL
      SELECT COUNT(*) FROM payment_provider_customers ppc
      WHERE ppc.type = 'PaymentProviderCustomers::StripeCustomer'
        AND ppc.settings->>'payment_method_id' IS NOT NULL
        AND ppc.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM payment_methods pm
          WHERE pm.payment_provider_customer_id = ppc.id
            AND pm.provider_method_id = ppc.settings->>'payment_method_id'
        )
    SQL

    puts "##################################\nStarting payment methods backfill"
    puts "\n#### Checking for resources to fill ####"

    count = ActiveRecord::Base.connection.select_value(count_sql).to_i

    if count > 0
      pp "  -> #{count} provider customers to migrate 🧮"
      puts "\n#### Enqueue job in the low_priority queue ####"
      pp "- Enqueuing DatabaseMigrations::BackfillStripePaymentMethodsJob"
      DatabaseMigrations::BackfillStripePaymentMethodsJob.perform_later
    else
      pp "  -> Nothing to do ✅"
    end

    while count > 0
      sleep 5
      puts "\n#### Checking status ####"

      count = ActiveRecord::Base.connection.select_value(count_sql).to_i

      if count > 0
        pp "  -> #{count} remaining 🧮"
      else
        pp "  -> Done ✅"
      end
    end

    puts "\n#### All good! ✅ ####"
  end

  desc "Backfill payment methods from existing Adyen provider customers"
  task backfill_adyen_payment_methods: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    count_sql = <<~SQL
      SELECT COUNT(*) FROM payment_provider_customers ppc
      WHERE ppc.type = 'PaymentProviderCustomers::AdyenCustomer'
        AND ppc.settings->>'payment_method_id' IS NOT NULL
        AND ppc.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM payment_methods pm
          WHERE pm.payment_provider_customer_id = ppc.id
            AND pm.provider_method_id = ppc.settings->>'payment_method_id'
        )
    SQL

    puts "##################################\nStarting Adyen payment methods backfill"
    puts "\n#### Checking for resources to fill ####"

    count = ActiveRecord::Base.connection.select_value(count_sql).to_i

    if count > 0
      pp "  -> #{count} provider customers to migrate 🧮"
      puts "\n#### Enqueue job in the low_priority queue ####"
      pp "- Enqueuing DatabaseMigrations::BackfillAdyenPaymentMethodsJob"
      DatabaseMigrations::BackfillAdyenPaymentMethodsJob.perform_later
    else
      pp "  -> Nothing to do ✅"
    end

    while count > 0
      sleep 5
      puts "\n#### Checking status ####"

      count = ActiveRecord::Base.connection.select_value(count_sql).to_i

      if count > 0
        pp "  -> #{count} remaining 🧮"
      else
        pp "  -> Done ✅"
      end
    end

    puts "\n#### All good! ✅ ####"
  end

  desc "Backfill payment methods from existing GoCardless provider customers"
  task backfill_gocardless_payment_methods: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    count_sql = <<~SQL
      SELECT COUNT(*) FROM payment_provider_customers ppc
      WHERE ppc.type = 'PaymentProviderCustomers::GocardlessCustomer'
        AND ppc.settings->>'provider_mandate_id' IS NOT NULL
        AND ppc.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM payment_methods pm
          WHERE pm.payment_provider_customer_id = ppc.id
            AND pm.provider_method_id = ppc.settings->>'provider_mandate_id'
        )
    SQL

    puts "##################################\nStarting GoCardless payment methods backfill"
    puts "\n#### Checking for resources to fill ####"

    count = ActiveRecord::Base.connection.select_value(count_sql).to_i

    if count > 0
      pp "  -> #{count} provider customers to migrate 🧮"
      puts "\n#### Enqueue job in the low_priority queue ####"
      pp "- Enqueuing DatabaseMigrations::BackfillGocardlessPaymentMethodsJob"
      DatabaseMigrations::BackfillGocardlessPaymentMethodsJob.perform_later
    else
      pp "  -> Nothing to do ✅"
    end

    while count > 0
      sleep 5
      puts "\n#### Checking status ####"

      count = ActiveRecord::Base.connection.select_value(count_sql).to_i

      if count > 0
        pp "  -> #{count} remaining 🧮"
      else
        pp "  -> Done ✅"
      end
    end

    puts "\n#### All good! ✅ ####"
  end

  desc "Backfill payment methods from existing Moneyhash provider customers"
  task backfill_moneyhash_payment_methods: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    count_sql = <<~SQL
      SELECT COUNT(*) FROM payment_provider_customers ppc
      WHERE ppc.type = 'PaymentProviderCustomers::MoneyhashCustomer'
        AND ppc.settings->>'payment_method_id' IS NOT NULL
        AND ppc.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM payment_methods pm
          WHERE pm.payment_provider_customer_id = ppc.id
            AND pm.provider_method_id = ppc.settings->>'payment_method_id'
        )
    SQL

    puts "##################################\nStarting Moneyhash payment methods backfill"
    puts "\n#### Checking for resources to fill ####"

    count = ActiveRecord::Base.connection.select_value(count_sql).to_i

    if count > 0
      pp "  -> #{count} provider customers to migrate 🧮"
      puts "\n#### Enqueue job in the low_priority queue ####"
      pp "- Enqueuing DatabaseMigrations::BackfillMoneyhashPaymentMethodsJob"
      DatabaseMigrations::BackfillMoneyhashPaymentMethodsJob.perform_later
    else
      pp "  -> Nothing to do ✅"
    end

    while count > 0
      sleep 5
      puts "\n#### Checking status ####"

      count = ActiveRecord::Base.connection.select_value(count_sql).to_i

      if count > 0
        pp "  -> #{count} remaining 🧮"
      else
        pp "  -> Done ✅"
      end
    end

    puts "\n#### All good! ✅ ####"
  end
end
