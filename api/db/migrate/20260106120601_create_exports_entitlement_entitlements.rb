# frozen_string_literal: true

class CreateExportsEntitlementEntitlements < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_entitlement_entitlements
  end
end
