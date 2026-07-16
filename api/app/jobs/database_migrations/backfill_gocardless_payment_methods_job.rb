# frozen_string_literal: true

module DatabaseMigrations
  class BackfillGocardlessPaymentMethodsJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1_000

    def perform(organization_id = nil, batch_number = 1)
      unless pending_work?(organization_id)
        Rails.logger.info("Finished backfilling GoCardless payment methods")
        return
      end

      org_filter = organization_id ? "AND ppc.organization_id = '#{organization_id}'" : ""

      result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
        WITH batch AS (
          SELECT
            ppc.id AS ppc_id,
            ppc.organization_id,
            ppc.customer_id,
            ppc.payment_provider_id,
            ppc.provider_customer_id,
            ppc.settings->>'provider_mandate_id' AS provider_method_id
          FROM payment_provider_customers ppc
          WHERE ppc.type = 'PaymentProviderCustomers::GocardlessCustomer'
            AND ppc.settings->>'provider_mandate_id' IS NOT NULL
            AND ppc.deleted_at IS NULL
            #{org_filter}
            AND NOT EXISTS (
              SELECT 1 FROM payment_methods pm
              WHERE pm.payment_provider_customer_id = ppc.id
                AND pm.provider_method_id = ppc.settings->>'provider_mandate_id'
            )
          LIMIT #{BATCH_SIZE}
        )
        INSERT INTO payment_methods (
          id,
          organization_id,
          customer_id,
          payment_provider_id,
          payment_provider_customer_id,
          provider_method_id,
          provider_method_type,
          is_default,
          details,
          created_at,
          updated_at
        )
        SELECT
          gen_random_uuid(),
          batch.organization_id,
          batch.customer_id,
          batch.payment_provider_id,
          batch.ppc_id,
          batch.provider_method_id,
          'card',
          true,
          jsonb_build_object('provider_customer_id', batch.provider_customer_id, 'from_migration', true),
          NOW(),
          NOW()
        FROM batch
      SQL

      self.class.perform_later(organization_id, batch_number + 1) if result.cmd_tuples.positive?
    end

    def lock_key_arguments
      [arguments]
    end

    private

    def pending_work?(organization_id)
      scope = PaymentProviderCustomers::GocardlessCustomer
        .where("settings->>'provider_mandate_id' IS NOT NULL")
        .where(
          "NOT EXISTS (
            SELECT 1 FROM payment_methods pm
            WHERE pm.payment_provider_customer_id = payment_provider_customers.id
              AND pm.provider_method_id = payment_provider_customers.settings->>'provider_mandate_id'
          )"
        )
      scope = scope.where(organization_id:) if organization_id
      scope.exists?
    end
  end
end
