# frozen_string_literal: true

class RemoveEntitlementSubscriptionEntitlementsView < ActiveRecord::Migration[8.0]
  def change
    drop_view :entitlement_subscription_entitlements_view, revert_to_version: 2
  end
end
