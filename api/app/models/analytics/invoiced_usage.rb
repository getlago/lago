# frozen_string_literal: true

module Analytics
  class InvoicedUsage < Base
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
          and_currency_sql = sanitize_sql(["AND trpmb.currency = :currency", args[:currency].upcase])
        end

        sql = <<~SQL.squish
          WITH organization_creation_date AS (
            SELECT
              DATE_TRUNC('month', o.created_at) AS start_month
            FROM organizations o
            WHERE o.id = :organization_id
          ),
          all_months AS (
            SELECT
              generate_series(
                (SELECT start_month FROM organization_creation_date),
                DATE_TRUNC('month', CURRENT_DATE + INTERVAL '10 years'),
                interval '1 month'
              ) AS month
          ),
          usage_fees AS (
            SELECT
              f.id,
              f.charge_id,
              (f.amount_cents::float - f.precise_coupons_amount_cents::float) AS amount_cents,
              f.amount_currency AS currency,
              f.created_at AS fee_created_at
            FROM fees f
            LEFT JOIN invoices i ON f.invoice_id = i.id
            LEFT JOIN subscriptions s ON s.id = f.subscription_id
            LEFT JOIN customers c ON c.id = s.customer_id
            WHERE f.invoiceable_type = 'Charge'
            AND f.fee_type = 0
            AND i.self_billed IS FALSE
            AND i.payment_dispute_lost_at IS NULL
            #{and_billing_entity_id_sql}
            AND c.organization_id = :organization_id
          ),
          total_revenue_per_bm AS (
            SELECT
              DATE_TRUNC('month', uf.fee_created_at) AS month,
              bm.code,
              uf.currency,
              COALESCE(SUM(amount_cents), 0) AS amount_cents
            FROM usage_fees uf
            LEFT JOIN charges c ON c.id = uf.charge_id
            LEFT JOIN billable_metrics bm ON bm.id = c.billable_metric_id
            GROUP BY month, bm.code, currency
            ORDER BY month
          )
          SELECT
            am.month,
            trpmb.code,
            trpmb.currency,
            trpmb.amount_cents
          FROM all_months AS am
          LEFT JOIN total_revenue_per_bm trpmb ON trpmb.month = am.month
          WHERE am.month <= DATE_TRUNC('month', CURRENT_DATE)
          #{and_months_sql}
          #{and_currency_sql}
          AND trpmb.currency IS NOT NULL
          AND trpmb.amount_cents IS NOT NULL
          ORDER BY am.month DESC, trpmb.amount_cents DESC;
        SQL

        sanitize_sql([sql, {organization_id:}.merge(args)])
      end

      def cache_key(organization_id, **args)
        [
          "invoiced-usage",
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
