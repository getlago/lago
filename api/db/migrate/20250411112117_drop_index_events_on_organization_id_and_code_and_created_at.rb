# frozen_string_literal: true

class DropIndexEventsOnOrganizationIdAndCodeAndCreatedAt < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :events, name: :index_events_on_organization_id_and_code_and_created_at, algorithm: :concurrently, if_exists: true
  end
end
