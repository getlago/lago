# frozen_string_literal: true

class ValidateCouponTargetsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :coupon_targets, :organizations
  end
end
