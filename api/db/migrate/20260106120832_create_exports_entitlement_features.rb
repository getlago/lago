# frozen_string_literal: true

class CreateExportsEntitlementFeatures < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_entitlement_features
  end
end
