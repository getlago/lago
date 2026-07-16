# frozen_string_literal: true

class AddOrganizationIdToAppliedCoupons < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :applied_coupons, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
