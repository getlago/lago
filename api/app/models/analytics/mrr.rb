# frozen_string_literal: true

module Analytics
  class Mrr < Base
    self.abstract_class = true

    class << self
      def query(organization_id, **args)
        if args[:billing_entity_id].present?
          and_billing_entity_id_sql = sanitize_sql(["AND i.billing_entity_id = :billing_entity_id", args[:billing_entity_id]])
        end

        if args[:months].present?
          months_interval = (args[:months].to_i <= 1) ? 0 : args[:months].to_i - 1

          and_months_sql = sanitize_sql(
            [
              "AND am.month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL ':months months')",
              {months: months_interval}
            ]
          )
        end

        if args[:currency].present?
          and_currency_sql = sanitize_sql(["AND cm.currency = :currency", args[:currency].upcase])
        end

        sql = <<~SQL.squish
          WITH organization_creation_date AS (
            SELECT
              DATE_TRUNC('month', o.created_at) AS month
            FROM organizations o
            WHERE o.id = :organization_id
          ),
          all_months AS (
            SELECT
              *
            FROM generate_series(
              (SELECT min(month) FROM organization_creation_date),
              date_trunc('month', now()) + interval '10 years',
              interval '1 month'
            ) AS month
          ),
          invoice_details AS (
            SELECT
              f.subscription_id,
              f.invoice_id,
              c.name,
              ((f.amount_cents - f.precise_coupons_amount_cents) + f.taxes_amount_cents) AS amount_cents,
              f.amount_currency AS currency,
              i.issuing_date,
              (EXTRACT(DAY FROM CAST(properties ->> 'to_datetime' AS timestamp) - CAST(properties ->> 'from_datetime' AS timestamp))
              + EXTRACT(HOUR FROM CAST(properties ->> 'to_datetime' AS timestamp) - CAST(properties ->> 'from_datetime' AS timestamp)) / 24
              + EXTRACT(MINUTE FROM CAST(properties ->> 'to_datetime' AS timestamp) - CAST(properties ->> 'from_datetime' AS timestamp)) / 1440) / 30.44 AS billed_months,
              p.pay_in_advance,
              CASE
                WHEN p.interval = 0 THEN 'weekly'
                WHEN p.interval = 1 THEN 'monthly'
                WHEN p.interval = 2 THEN 'yearly'
                WHEN p.interval = 3 THEN 'quarterly'
                WHEN p.interval = 4 THEN 'semiannual'
              END AS plan_interval
            FROM fees f
            LEFT JOIN invoices i ON f.invoice_id = i.id
            LEFT JOIN customers c ON c.id = i.customer_id
            LEFT JOIN organizations o ON o.id = c.organization_id
            LEFT JOIN subscriptions s ON f.subscription_id = s.id
            LEFT JOIN plans p ON p.id = s.plan_id
            WHERE fee_type = 2
              AND c.organization_id = :organization_id
              AND i.self_billed IS FALSE
              AND i.status = 1
              AND i.payment_dispute_lost_at IS NULL
              #{and_billing_entity_id_sql}
            ORDER BY issuing_date ASC
          ),
          quarterly_advance AS (
            SELECT
              DATE_TRUNC('month', issuing_date) + INTERVAL '1 month' * gs.month_index AS month,
              CASE
                  WHEN gs.month_index = 0 THEN (amount_cents / billed_months) * (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))
                  WHEN gs.month_index = CEIL(billed_months) - 1 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 1 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                  ELSE amount_cents / billed_months
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months) - 1) AS gs(month_index)
            WHERE pay_in_advance = TRUE
            AND plan_interval = 'quarterly'
          ),
          quarterly_arrears AS (
            SELECT
              DATE_TRUNC('month', issuing_date) - INTERVAL '1 month' * gs.month_index AS month,
              CASE
                  WHEN gs.month_index < CEIL(billed_months::numeric) - 1 THEN
                      amount_cents::numeric / billed_months::numeric
                  ELSE
                      amount_cents::numeric - (amount_cents::numeric / billed_months::numeric) * (CEIL(billed_months::numeric) - 1)
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months::numeric) - 1) AS gs(month_index)
            WHERE pay_in_advance = FALSE
            AND plan_interval = 'quarterly'
          ),
          semiannual_advance AS (
            SELECT
              DATE_TRUNC('month', issuing_date) + INTERVAL '1 month' * gs.month_index AS month,
              CASE
                  WHEN gs.month_index = 0 THEN (amount_cents / billed_months) * (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))
                  WHEN gs.month_index = CEIL(billed_months) - 1 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 1 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                  WHEN gs.month_index = CEIL(billed_months) - 2 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 2 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                  WHEN gs.month_index = CEIL(billed_months) - 3 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 3 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                  WHEN gs.month_index = CEIL(billed_months) - 4 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 4 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                  ELSE amount_cents / billed_months
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months) - 1) AS gs(month_index)
            WHERE pay_in_advance = TRUE
            AND plan_interval = 'semiannual'
          ),
          semiannual_arrears AS (
            SELECT
              DATE_TRUNC('month', issuing_date) - INTERVAL '1 month' * gs.month_index AS month,
              CASE
                WHEN gs.month_index < CEIL(billed_months::numeric) - 1 THEN
                  amount_cents::numeric / billed_months::numeric
                ELSE
                  amount_cents::numeric - (amount_cents::numeric / billed_months::numeric) * (CEIL(billed_months::numeric) - 1)
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months::numeric) - 1) AS gs(month_index)
            WHERE pay_in_advance = FALSE
            AND plan_interval = 'semiannual'
          ),
          yearly_advance AS (
            SELECT
              DATE_TRUNC('month', issuing_date) + INTERVAL '1 month' * gs.month_index AS month,
              CASE
                WHEN gs.month_index = 0 THEN (amount_cents / billed_months) * (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))
                WHEN gs.month_index = CEIL(billed_months) - 1 THEN (amount_cents - (amount_cents / billed_months) * (FLOOR(billed_months) - 1 + (DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - issuing_date) / DATE_PART('day', DATE_TRUNC('month', issuing_date + INTERVAL '1 month') - DATE_TRUNC('month', issuing_date)))))
                ELSE amount_cents / billed_months
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months) - 1) AS gs(month_index)
            WHERE pay_in_advance = TRUE
            AND plan_interval = 'yearly'
          ),
          yearly_arrears AS (
            SELECT
              DATE_TRUNC('month', issuing_date) - INTERVAL '1 month' * gs.month_index AS month,
              CASE
                WHEN gs.month_index < CEIL(billed_months::numeric) - 1 THEN
                  amount_cents::numeric / billed_months::numeric
                ELSE
                  amount_cents::numeric - (amount_cents::numeric / billed_months::numeric) * (CEIL(billed_months::numeric) - 1)
              END AS amount_cents,
              currency,
              name
            FROM invoice_details,
            LATERAL GENERATE_SERIES(0, CEIL(billed_months::numeric) - 1) AS gs(month_index)
            WHERE pay_in_advance = FALSE
            AND plan_interval = 'yearly'
          ),
          monthly AS (
            SELECT
              DATE_TRUNC('month', issuing_date) - interval '1 month' * generate_series(0, 0, -1) AS month,
              amount_cents,
              currency
            FROM invoice_details
            WHERE plan_interval = 'monthly'
          ),
          weekly AS (
            SELECT
              DATE_TRUNC('month', issuing_date) - interval '1 month' * generate_series(0, 0, -1) AS month,
              currency,
              (SUM(amount_cents) / COUNT(*)) * 4.33 AS amount_cents
            FROM invoice_details
            WHERE plan_interval = 'weekly'
            GROUP BY month, currency
          ),
          consolidated_mrr AS (
            SELECT month, amount_cents::numeric, currency
            FROM quarterly_arrears
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM quarterly_advance
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM semiannual_arrears
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM semiannual_advance
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM yearly_arrears
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM yearly_advance
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM monthly
            UNION ALL
            SELECT month, amount_cents::numeric, currency
            FROM weekly
          )
          SELECT
            am.month,
            cm.currency,
            SUM(cm.amount_cents) AS amount_cents
          FROM all_months am
          LEFT JOIN consolidated_mrr cm ON cm.month = am.month
          WHERE am.month <= DATE_TRUNC('month', CURRENT_DATE)
          #{and_months_sql}
          #{and_currency_sql}
          GROUP BY am.month, cm.currency
          ORDER BY am.month ASC
        SQL

        sanitize_sql([sql, {organization_id:}.merge(args)])
      end

      def cache_key(organization_id, **args)
        [
          "mrr",
          Date.current.strftime("%Y-%m-%d"),
          organization_id,
          args[:billing_entity_id],
          args[:currency],
          args[:months]
        ].join("/")
      end
    end
  end
end
