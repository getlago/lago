# frozen_string_literal: true

# Wraps a FixedCharge with a pre-resolved override units value so `#units`
# returns the per-subscription override when one exists, falling back to
# the plan-level units otherwise. Used by the GraphQL Subscription type
# to expose subscription-aware units without changing the FixedCharge
# GraphQL type's contract. Callers must batch the override lookup once
# per request (see `Subscription::FixedChargeUnitsOverride.units_map_for`)
# and pass the matching value as `effective_units:` — `nil` means "no
# override". Every other method is delegated to the wrapped FixedCharge.
class Subscription::FixedChargePresenter < SimpleDelegator
  attr_reader :subscription

  def initialize(fixed_charge, subscription, effective_units:)
    super(fixed_charge)
    @subscription = subscription
    @effective_units = effective_units
  end

  def units
    @effective_units || __getobj__.units
  end
end
