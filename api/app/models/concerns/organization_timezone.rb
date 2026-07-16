# frozen_string_literal: true

module OrganizationTimezone
  ORGANIZATION_SUFFIX = "_in_organization_timezone"

  def method_missing(method_name, *arguments, &block)
    return super unless method_name.to_s.end_with?(ORGANIZATION_SUFFIX)

    target = if is_a?(Organization)
      self
    else
      organization
    end

    initial_method_name = method_name.to_s.gsub(ORGANIZATION_SUFFIX, "")
    __send__(initial_method_name)&.in_time_zone(target.timezone)
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.end_with?(ORGANIZATION_SUFFIX) && respond_to?(
      method_name.gsub(ORGANIZATION_SUFFIX, "")
    ) || super
  end

  def self.included(base)
    base.extend(self)
  end
end
