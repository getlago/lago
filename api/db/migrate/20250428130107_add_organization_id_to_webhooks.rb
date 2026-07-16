# frozen_string_literal: true

class AddOrganizationIdToWebhooks < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :webhooks, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
