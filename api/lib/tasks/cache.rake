# frozen_string_literal: true

namespace :cache do
  desc "Reset the current usage cache for migration from group to filters"
  task remove_group_usage_cache: :environment do
    charge_id = Charge.joins(:group_properties).select(:id)

    Charge.where(id: charge_id).includes(plan: :subscriptions).find_each do |charge|
      charge.plan.subscriptions.find_each do |subscription|
        Subscriptions::ChargeCacheService.expire_for_subscription_charge(subscription:, charge:)
      end
    end
  end

  desc "Expire cache for a given subscription"
  task expire_subscription_cache: :environment do
    subscription = Subscription.find(ENV["subscription_id"])
    puts "Expiring cache for subscription #{subscription.id}"

    Subscriptions::ChargeCacheService.expire_for_subscription(subscription)
  end
end
