# frozen_string_literal: true

module DatabaseMigrations
  class BackfillStripePaymentMethodCardDetailsJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1_000

    def perform(organization_id = nil, batch_number = 1)
      return Rails.logger.info("Finished backfilling payment method card details") unless pending_work?(organization_id)

      org_filter = organization_id ? "AND pm.organization_id = '#{organization_id}'" : ""

      result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
        WITH batch AS (
          SELECT
            pm.id,
            pm.payment_provider_customer_id,
            pm.provider_method_id
          FROM payment_methods pm
          WHERE pm.details->>'from_migration' = 'true'
            AND pm.details->>'last4' IS NULL
            AND pm.deleted_at IS NULL
            #{org_filter}
            AND EXISTS (
              SELECT 1 FROM payments p
              WHERE p.payment_provider_customer_id = pm.payment_provider_customer_id
                AND p.provider_payment_method_id = pm.provider_method_id
                AND p.provider_payment_method_data->>'last4' IS NOT NULL
            )
          LIMIT #{BATCH_SIZE}
        ),
        last_payment_data AS (
          SELECT DISTINCT ON (p.payment_provider_customer_id, p.provider_payment_method_id)
            p.payment_provider_customer_id,
            p.provider_payment_method_id,
            p.provider_payment_method_data
          FROM payments p
          WHERE p.provider_payment_method_data->>'last4' IS NOT NULL
            AND EXISTS (
              SELECT 1 FROM batch b
              WHERE b.payment_provider_customer_id = p.payment_provider_customer_id
                AND b.provider_method_id = p.provider_payment_method_id
            )
          ORDER BY p.payment_provider_customer_id, p.provider_payment_method_id, p.created_at DESC
        )
        UPDATE payment_methods pm
        SET
          details = pm.details || jsonb_strip_nulls(jsonb_build_object(
            'type', lpd.provider_payment_method_data->>'type',
            'brand', lpd.provider_payment_method_data->>'brand',
            'last4', lpd.provider_payment_method_data->>'last4',
            'expiration_month', lpd.provider_payment_method_data->'expiration_month',
            'expiration_year', lpd.provider_payment_method_data->'expiration_year'
          )),
          updated_at = NOW()
        FROM batch
        INNER JOIN last_payment_data lpd
          ON lpd.payment_provider_customer_id = batch.payment_provider_customer_id
          AND lpd.provider_payment_method_id = batch.provider_method_id
        WHERE pm.id = batch.id
      SQL

      if result.cmd_tuples.positive?
        self.class.perform_later(organization_id, batch_number + 1)
      else
        Rails.logger.info("Finished backfilling payment method card details")
      end
    end

    def lock_key_arguments
      [arguments]
    end

    private

    def pending_work?(organization_id)
      scope = PaymentMethod.unscoped
        .where("details->>'from_migration' = 'true'")
        .where("details->>'last4' IS NULL")
        .where("deleted_at IS NULL")
        .where(
          "EXISTS (
            SELECT 1 FROM payments p
            WHERE p.payment_provider_customer_id = payment_methods.payment_provider_customer_id
              AND p.provider_payment_method_id = payment_methods.provider_method_id
              AND p.provider_payment_method_data->>'last4' IS NOT NULL
          )"
        )
      scope = scope.where(organization_id:) if organization_id
      scope.exists?
    end
  end
end
