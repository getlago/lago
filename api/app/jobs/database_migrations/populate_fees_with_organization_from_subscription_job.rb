# frozen_string_literal: true

module DatabaseMigrations
  class PopulateFeesWithOrganizationFromSubscriptionJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1000

    def perform(batch_number = 1)
      batch = Fee.unscoped.where(organization_id: nil).where.not(subscription_id: nil)
        .joins(subscription: :customer).limit(BATCH_SIZE)

      if batch.exists?
        # rubocop:disable Rails/SkipsModelValidations
        batch.update_all(
          "organization_id = (SELECT customers.organization_id FROM subscriptions
                            JOIN customers ON customers.id = subscriptions.customer_id
                            WHERE subscriptions.id = fees.subscription_id),
           billing_entity_id = (SELECT customers.organization_id FROM subscriptions
                              JOIN customers ON customers.id = subscriptions.customer_id
                              WHERE subscriptions.id = fees.subscription_id)"
        )
        # rubocop:enable Rails/SkipsModelValidations
        # Queue the next batch
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished the execution")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
