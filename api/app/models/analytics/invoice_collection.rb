# frozen_string_literal: true

module Analytics
  class InvoiceCollection < Base
    self.abstract_class = true

    class << self
      def query(organization_id, **args)
        if args[:billing_entity_id].present?
          and_billing_entity_id_sql = sanitize_sql(["AND i.billing_entity_id = :billing_entity_id", args[:billing_entity_id]])
        end

        if args[:billing_entity_code].present?
          and_billing_entity_code_sql = sanitize_sql(
            ["AND be.code = :billing_entity_code", args[:billing_entity_code]]
          )
        end

        if args[:external_customer_id].present?
          and_external_customer_id_sql = sanitize_sql(
            ["AND c.external_id = :external_customer_id AND c.deleted_at IS NULL", args[:external_customer_id]]
          )
        end

        unless args[:is_customer_tin_empty].nil?
          and_is_customer_tin_empty_sql =
            if args[:is_customer_tin_empty] == true
              sanitize_sql(["AND (c.tax_identification_number IS NULL OR trim(c.tax_identification_number) = '')"])
            else
              sanitize_sql(["AND (c.tax_identification_number IS NOT NULL AND trim(c.tax_identification_number) <> '')"])
            end
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
          and_currency_sql = sanitize_sql(["AND currency = :currency", args[:currency].upcase])
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
          invoices_per_status AS (
            SELECT
                DATE_TRUNC('month', i.issuing_date) AS month,
                i.currency,
                CASE
                    WHEN i.payment_status = 0 THEN 'pending'
                    WHEN i.payment_status = 1 THEN 'succeeded'
                    WHEN i.payment_status = 2 THEN 'failed'
                END AS payment_status,
                COALESCE(COUNT(*), 0) AS invoices_count,
                COALESCE(SUM(i.total_amount_cents::float), 0) AS amount_cents
            FROM invoices i
            LEFT JOIN customers c ON i.customer_id = c.id
            LEFT JOIN billing_entities be ON i.billing_entity_id = be.id
            WHERE i.organization_id = :organization_id
            AND i.self_billed IS FALSE
            AND i.status = 1
            AND i.payment_dispute_lost_at IS NULL
            #{and_external_customer_id_sql}
            #{and_is_customer_tin_empty_sql}
            #{and_billing_entity_id_sql}
            #{and_billing_entity_code_sql}
            GROUP BY payment_status, month, i.currency
          )
          SELECT
            am.month,
            payment_status,
            ips.currency,
            COALESCE(invoices_count, 0) AS invoices_count,
            COALESCE(amount_cents, 0) AS amount_cents
          FROM all_months am
          LEFT JOIN invoices_per_status ips ON ips.month = am.month AND ips.payment_status IS NOT NULL
          WHERE am.month <= DATE_TRUNC('month', CURRENT_DATE)
          #{and_months_sql}
          #{and_currency_sql}
          ORDER BY am.month, payment_status, ips.currency;
        SQL

        sanitize_sql([sql, {organization_id:}.merge(args)])
      end

      def cache_key(organization_id, **args)
        [
          "invoice-collection",
          Date.current.strftime("%Y-%m-%d"),
          organization_id,
          args[:billing_entity_id],
          args[:external_customer_id],
          args[:currency],
          args[:months]
        ].join("/")
      end

      def expire_cache_for_customer(organization_id, external_customer_id)
        Rails.cache.delete_matched(
          "invoice-collection/#{Date.current.strftime("%Y-%m-%d")}/#{organization_id}*#{external_customer_id}*"
        )
      end
    end
  end
end
