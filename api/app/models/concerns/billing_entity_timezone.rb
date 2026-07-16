# frozen_string_literal: true

module BillingEntityTimezone
  BILLING_ENTITY_SUFFIX = "_in_billing_entity_timezone"

  def method_missing(method_name, *arguments, &block)
    return super unless method_name.to_s.end_with?(BILLING_ENTITY_SUFFIX)

    target = if is_a?(BillingEntity)
      self
    else
      billing_entity
    end

    initial_method_name = method_name.to_s.gsub(BILLING_ENTITY_SUFFIX, "")
    __send__(initial_method_name)&.in_time_zone(target.timezone)
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.end_with?(BILLING_ENTITY_SUFFIX) && respond_to?(
      method_name.gsub(BILLING_ENTITY_SUFFIX, "")
    ) || super
  end

  def self.included(base)
    base.extend(self)
  end
end
