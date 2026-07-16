# frozen_string_literal: true

class AddOrganizationIdToCouponTargets < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :coupon_targets, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
