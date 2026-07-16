# frozen_string_literal: true

module Types
  module Entitlement
    class PrivilegeObject < Types::BaseObject
      field :id, ID, null: false

      field :code, String, null: false
      field :config, Types::Entitlement::PrivilegeConfigObject, null: false
      field :name, String, null: true
      field :value_type, Types::Entitlement::PrivilegeValueTypeEnum, null: false
    end
  end
end
