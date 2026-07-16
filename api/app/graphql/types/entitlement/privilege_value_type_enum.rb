# frozen_string_literal: true

module Types
  module Entitlement
    class PrivilegeValueTypeEnum < Types::BaseEnum
      ::Entitlement::Privilege::VALUE_TYPES.each do |value_type|
        value value_type
      end
    end
  end
end
