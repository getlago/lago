# frozen_string_literal: true

module Wallets
  class CreateIntervalWalletTransactionsService < BaseService
    Result = BaseResult

    def call
      recurring_transaction_rules.each do |rule|
        ongoing_balance = rule.wallet.credits_ongoing_balance
        paid_credits = rule.compute_paid_credits(ongoing_balance:)
        granted_credits = rule.compute_granted_credits

        next if rule.target? && paid_credits.zero? && granted_credits.zero?

        params = {
          wallet_id: rule.wallet.id,
          paid_credits: paid_credits.to_s,
          granted_credits: granted_credits.to_s,
          source: :interval,
          invoice_requires_successful_payment: rule.invoice_requires_successful_payment?,
          metadata: rule.transaction_metadata,
          name: rule.transaction_name
        }

        params[:invoice_custom_section] = rule.invoice_custom_section_params if rule.invoice_custom_section_params

        WalletTransactions::CreateJob.perform_later(
          organization_id: rule.wallet.organization.id,
          params:
        )
      end

      result
    end

    private

    def today
      @today ||= Time.current
    end

    # NOTE: Retrieve list of recurring_transaction_rules that should create wallet transactions today
    def recurring_transaction_rules
      sql = <<-SQL
        WITH
          pending_recurring_rules AS (
            -- Anniversary rules
            (#{weekly_anniversary})
            UNION
            (#{monthly_anniversary})
            UNION
            (#{quarterly_anniversary})
            UNION
            (#{semiannual_anniversary})
            UNION
            (#{yearly_anniversary})
          ),
          -- Filter wallets which rules are already applied today (in customer's applicable timezone)
          already_applied_today AS (#{already_applied_today})

        SELECT DISTINCT(recurring_transaction_rules.*)
        FROM recurring_transaction_rules
          INNER JOIN pending_recurring_rules ON pending_recurring_rules.rule_id = recurring_transaction_rules.id
          INNER JOIN wallets ON wallets.id = recurring_transaction_rules.wallet_id
          INNER JOIN customers ON customers.id = wallets.customer_id
          INNER JOIN billing_entities ON billing_entities.id = customers.billing_entity_id
          LEFT JOIN already_applied_today ON already_applied_today.wallet_id = wallets.id
        WHERE
          -- Exclude top-ups already applied today
          already_applied_today.top_up_count IS NULL
          -- Do not take into account wallets that are created today
          AND DATE(wallets.created_at#{at_time_zone}) != DATE(:today#{at_time_zone})
        GROUP BY recurring_transaction_rules.id
      SQL

      RecurringTransactionRule.find_by_sql([sql, {today:}])
    end

    def base_recurring_transaction_rule_scope(interval: nil, conditions: nil)
      <<-SQL
        SELECT recurring_transaction_rules.id AS rule_id
        FROM recurring_transaction_rules
          INNER JOIN wallets ON wallets.id = recurring_transaction_rules.wallet_id
          INNER JOIN customers ON customers.id = wallets.customer_id
          INNER JOIN billing_entities ON billing_entities.id = customers.billing_entity_id
        WHERE wallets.status = #{Wallet.statuses[:active]}
          AND recurring_transaction_rules.status = #{RecurringTransactionRule.statuses[:active]}
          AND recurring_transaction_rules.trigger = #{RecurringTransactionRule.triggers[:interval]}
          AND recurring_transaction_rules.interval = #{RecurringTransactionRule.intervals[interval]}
          AND #{wallet_started_at} <= :today
          AND (recurring_transaction_rules.expiration_at IS NULL
           OR recurring_transaction_rules.expiration_at > '#{Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")}')
          AND #{conditions.join(" AND ")}
        GROUP BY recurring_transaction_rules.id
      SQL
    end

    def weekly_anniversary
      base_recurring_transaction_rule_scope(
        interval: :weekly,
        conditions: [
          "EXTRACT(ISODOW FROM (#{wallet_started_at})) =
          EXTRACT(ISODOW FROM (:today#{at_time_zone}))"
        ]
      )
    end

    def monthly_anniversary
      base_recurring_transaction_rule_scope(
        interval: :monthly,
        conditions: [<<-SQL]
          DATE_PART('day', (#{wallet_started_at})) = ANY (
            -- Check if today is the last day of the month
            CASE WHEN DATE_PART('day', (#{end_of_month})) = DATE_PART('day', :today#{at_time_zone})
            THEN
              -- If so and if it counts less than 31 days, we need to take all days up to 31 into account
              (SELECT ARRAY(SELECT generate_series(DATE_PART('day', :today#{at_time_zone})::integer, 31)))
            ELSE
              -- Otherwise, we just need the current day
              (SELECT ARRAY[DATE_PART('day', :today#{at_time_zone})])
            END
          )
        SQL
      )
    end

    # NOTE: Billed quarterly on anniversary date
    def quarterly_anniversary
      billing_day = <<-SQL
        DATE_PART('day', (#{wallet_started_at})) = ANY (
          -- Check if today is the last day of the month
          CASE WHEN DATE_PART('day', (#{end_of_month})) = DATE_PART('day', :today#{at_time_zone})
          THEN
            -- If so and if it counts less than 31 days, we need to take all days up to 31 into account
            (SELECT ARRAY(SELECT generate_series(DATE_PART('day', :today#{at_time_zone})::integer, 31)))
          ELSE
            -- Otherwise, we just need the current day
            (SELECT ARRAY[DATE_PART('day', :today#{at_time_zone})])
          END
        )
      SQL

      billing_month = <<-SQL
        (
          -- We need to avoid zero and instead of it use 12. E.g.: (3 + 9) % 12 = 0 -> 12
          CASE WHEN MOD(CAST(DATE_PART('month', (#{wallet_started_at})) AS INTEGER), 3) = 0
          THEN
            (DATE_PART('month', :today#{at_time_zone}) IN (3, 6, 9, 12))
          ELSE (
            DATE_PART('month', (#{wallet_started_at})) = DATE_PART('month', :today#{at_time_zone})
              OR MOD(CAST(DATE_PART('month', (#{wallet_started_at})) + 3 AS INTEGER), 12) = DATE_PART('month', :today#{at_time_zone})
              OR MOD(CAST(DATE_PART('month', (#{wallet_started_at})) + 6 AS INTEGER), 12) = DATE_PART('month', :today#{at_time_zone})
              OR MOD(CAST(DATE_PART('month', (#{wallet_started_at})) + 9 AS INTEGER), 12) = DATE_PART('month', :today#{at_time_zone})
          )
          END
        )
      SQL

      base_recurring_transaction_rule_scope(
        interval: :quarterly,
        conditions: [billing_month, billing_day]
      )
    end

    # NOTE: Billed semiannually on anniversary date
    def semiannual_anniversary
      billing_day = <<-SQL
        DATE_PART('day', (#{wallet_started_at})) = ANY (
          -- Check if today is the last day of the month
          CASE WHEN DATE_PART('day', (#{end_of_month})) = DATE_PART('day', :today#{at_time_zone})
          THEN
            -- If so and if it counts less than 31 days, we need to take all days up to 31 into account
            (SELECT ARRAY(SELECT generate_series(DATE_PART('day', :today#{at_time_zone})::integer, 31)))
          ELSE
            -- Otherwise, we just need the current day
            (SELECT ARRAY[DATE_PART('day', :today#{at_time_zone})])
          END
        )
      SQL

      billing_month = <<-SQL
        (
          -- We need to avoid zero and instead of it use 12. E.g.: (3 + 9) % 12 = 0 -> 12
          CASE WHEN MOD(CAST(DATE_PART('month', (#{wallet_started_at})) AS INTEGER), 6) = 0
          THEN
            (DATE_PART('month', :today#{at_time_zone}) IN (6, 12))
          ELSE (
            DATE_PART('month', (#{wallet_started_at})) = DATE_PART('month', :today#{at_time_zone})
              OR MOD(CAST(DATE_PART('month', (#{wallet_started_at})) + 6 AS INTEGER), 12) = DATE_PART('month', :today#{at_time_zone})
          )
          END
        )
      SQL

      base_recurring_transaction_rule_scope(
        interval: :semiannual,
        conditions: [billing_month, billing_day]
      )
    end

    def yearly_anniversary
      billing_month = <<-SQL
        -- Ensure we are on the billing month
        DATE_PART('month', (#{wallet_started_at})) = DATE_PART('month', :today#{at_time_zone})
      SQL

      billing_day = <<-SQL
        -- Check if we are not in a leap year when today is february the 28th
        DATE_PART('day', (#{wallet_started_at})) = ANY (
          CASE WHEN (
            DATE_PART('month', :today#{at_time_zone}) = 2
            AND DATE_PART('day', :today#{at_time_zone}) = 28
            AND DATE_PART('day', (#{end_of_month})) = 28
          )
          THEN
            -- If not a leap year, we have to tale february the 29th into account
            ARRAY[28, 29]
          ELSE
            -- Otherwise, we just need the current day
            ARRAY[DATE_PART('day', :today#{at_time_zone})]
          END
        )
      SQL

      base_recurring_transaction_rule_scope(
        interval: :yearly,
        conditions: [billing_month, billing_day]
      )
    end

    def end_of_month
      <<-SQL
        (DATE_TRUNC('month', :today#{at_time_zone}) + INTERVAL '1 month - 1 day')::date
      SQL
    end

    def wallet_started_at
      <<-SQL
        COALESCE(
          recurring_transaction_rules.started_at#{at_time_zone},
          wallets.created_at#{at_time_zone}
        )
      SQL
    end

    def already_applied_today
      <<-SQL
        SELECT
          wallet_transactions.wallet_id,
          COUNT(wallet_transactions.id) AS top_up_count
        FROM wallet_transactions
          INNER JOIN wallets AS wal ON wallet_transactions.wallet_id = wal.id
          INNER JOIN customers AS cus ON wal.customer_id = cus.id
          INNER JOIN billing_entities ON cus.billing_entity_id = billing_entities.id
        WHERE wallet_transactions.source = #{WalletTransaction.sources[:interval]}
          AND wallet_transactions.transaction_type = #{WalletTransaction.transaction_types[:inbound]}
          AND DATE(
            (wallet_transactions.created_at)#{at_time_zone(customer: "cus", billing_entity: "billing_entities")}
          ) = DATE(:today#{at_time_zone(customer: "cus", billing_entity: "billing_entities")})
        GROUP BY wallet_transactions.wallet_id
      SQL
    end
  end
end
