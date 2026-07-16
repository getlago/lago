# frozen_string_literal: true

class UpdateEntitlementSubscriptionEntitlementsView < ActiveRecord::Migration[8.0]
  def change
    update_view :entitlement_subscription_entitlements_view, version: 2, revert_to_version: 1
  end
end
