# frozen_string_literal: true

class AddEventCodeIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index(
      :events,
      [:external_subscription_id, :organization_id, :timestamp],
      include: [:code],
      name: :idx_events_for_distinct_codes,
      where: "deleted_at IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
    )
  end
end
