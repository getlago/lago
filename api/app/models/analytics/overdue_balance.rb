# frozen_string_literal: true

module Analytics
  class OverdueBalance < Base
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
          and_currency_sql = sanitize_sql(["AND invs.currency = :currency", args[:currency].upcase])
          select_currency_sql = sanitize_sql(["COALESCE(invs.currency, :currency) as currency", args[:currency].upcase])
        else
          select_currency_sql = "invs.currency"
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
          payment_overdue_invoices AS (
            SELECT
              DATE_TRUNC('month', payment_due_date) AS month,
              i.currency,
              i.billing_entity_id,
              COALESCE(SUM(
                i.total_amount_cents -
                i.total_paid_amount_cents -
                COALESCE(cn.offset_amount_cents_sum, 0)
               ), 0) AS total_amount_cents,
              array_agg(DISTINCT i.id) AS ids
            FROM invoices i
            LEFT JOIN customers c ON i.customer_id = c.id
            LEFT JOIN billing_entities be ON i.billing_entity_id = be.id
            LEFT JOIN (
              SELECT invoice_id, SUM(offset_amount_cents) AS offset_amount_cents_sum
              FROM credit_notes
              WHERE status = #{CreditNote.statuses[:finalized]}
              GROUP BY invoice_id
            ) cn ON cn.invoice_id = i.id
            WHERE i.organization_id = :organization_id
            AND i.self_billed IS FALSE
            AND i.payment_overdue IS TRUE
            #{and_external_customer_id_sql}
            #{and_billing_entity_id_sql}
            #{and_billing_entity_code_sql}
            GROUP BY month, i.currency, i.billing_entity_id, total_amount_cents
            ORDER BY month ASC
          )
          SELECT
            am.month,
            #{select_currency_sql},
            invs.billing_entity_id,
            SUM(invs.total_amount_cents) AS amount_cents,
            jsonb_agg(DISTINCT invs.ids) AS lago_invoice_ids
          FROM all_months am
          LEFT JOIN payment_overdue_invoices invs ON am.month = invs.month
          WHERE am.month <= DATE_TRUNC('month', CURRENT_DATE)
          #{and_months_sql}
          #{and_currency_sql}
          AND invs.total_amount_cents IS NOT NULL
          GROUP BY am.month, invs.currency, invs.billing_entity_id
          ORDER BY am.month;
        SQL

        sanitize_sql([sql, {organization_id:}.merge(args)])
      end

      def cache_key(organization_id, **args)
        [
          "overdue-balance",
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
          "overdue-balance/#{Date.current.strftime("%Y-%m-%d")}/#{organization_id}*#{external_customer_id}*"
        )
      end
    end
  end
end
