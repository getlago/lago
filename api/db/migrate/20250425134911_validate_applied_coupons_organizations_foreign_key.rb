# frozen_string_literal: true

class ValidateAppliedCouponsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :applied_coupons, :organizations
  end
end
