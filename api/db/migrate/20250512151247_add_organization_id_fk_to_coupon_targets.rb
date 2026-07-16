# frozen_string_literal: true

class AddOrganizationIdFkToCouponTargets < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :coupon_targets, :organizations, validate: false
  end
end
