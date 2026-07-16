# frozen_string_literal: true

class AddIndexOnFeesForOrganizationIdCreatedAtAndId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :fees,
      [:organization_id, :created_at, :id],
      where: "deleted_at IS NULL",
      name: :index_fees_on_organization_id_and_created_at_and_id,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
