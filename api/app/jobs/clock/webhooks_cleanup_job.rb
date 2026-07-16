# frozen_string_literal: true

module Clock
  class WebhooksCleanupJob < ClockJob
    unique :until_executed, on_conflict: :log

    class_attribute :batch_size, default: 1_000 # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :retention_period, default: 90.days # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    # NOTE: Manual batching is used instead of `in_batches` because the table can contain
    #   millions of rows. `in_batches` adds `ORDER BY id` which prevents PostgreSQL from
    #   using the covering index on `(updated_at) INCLUDE (id)`.
    #
    # NOTE: This only removes the database rows. The payload/response blobs stored on object
    #   storage under `webhooks/<date>/<uuid>/` (see Webhook#store_payload) are NOT deleted
    #   here. You should configure a bucket lifecycle rule to delete blobs older than `retention_period`.
    def perform
      loop do
        result = Webhook.where(
          id: Webhook.where("updated_at < ?", retention_period.ago).limit(batch_size).select(:id)
        ).delete_all

        break if result < batch_size
      end
    end
  end
end
