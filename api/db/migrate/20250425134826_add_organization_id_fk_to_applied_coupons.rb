# frozen_string_literal: true

class AddOrganizationIdFkToAppliedCoupons < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :applied_coupons, :organizations, validate: false
  end
end
