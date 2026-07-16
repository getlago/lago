# frozen_string_literal: true

module Entitlement
  class SubscriptionEntitlementPrivilege
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :organization_id, :string
    attribute :entitlement_feature_id, :string
    attribute :code, :string
    attribute :value, :string
    attribute :value_type, :string
    attribute :plan_value, :string
    attribute :subscription_value, :string
    attribute :name, :string
    attribute :value_type, :string
    attribute :config
    attribute :ordering_date, :datetime
    attribute :plan_entitlement_id, :string
    attribute :sub_entitlement_id, :string
    attribute :plan_entitlement_value_id, :string
    attribute :sub_entitlement_value_id, :string

    def config
      super.then { it.is_a?(String) ? JSON.parse(it) : it }
    end

    def to_h
      h = attributes
      h["config"] = config
      h.with_indifferent_access
    end
  end
end
