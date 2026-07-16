# frozen_string_literal: true

module CustomerTimezone
  CUSTOMER_SUFFIX = "_in_customer_timezone"

  def method_missing(method_name, *arguments, &block)
    return super unless method_name.to_s.end_with?(CUSTOMER_SUFFIX)

    target = if is_a?(Customer)
      self
    else
      customer
    end

    initial_method_name = method_name.to_s.gsub(CUSTOMER_SUFFIX, "")
    __send__(initial_method_name)&.in_time_zone(target.applicable_timezone)
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.end_with?(CUSTOMER_SUFFIX) && respond_to?(
      method_name.to_s.gsub(CUSTOMER_SUFFIX, "")
    ) || super
  end

  def self.included(base)
    base.extend(self)
  end
end
