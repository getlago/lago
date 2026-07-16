# frozen_string_literal: true

class BackfillCouponCodes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    Coupon.unscoped.where(code: nil).find_in_batches(batch_size: 1000) do |batch|
      Coupon.unscoped.where(id: batch.pluck(:id))
        .update_all("code = 'coupon-' || id::text") # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # irreversible
  end
end
