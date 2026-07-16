# frozen_string_literal: true

module Entitlement
  class Entitlement < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at

    default_scope -> { kept }

    belongs_to :organization
    belongs_to :feature, class_name: "Entitlement::Feature", foreign_key: :entitlement_feature_id
    belongs_to :plan, optional: true
    belongs_to :subscription, optional: true
    has_many :values, class_name: "Entitlement::EntitlementValue", foreign_key: :entitlement_entitlement_id, dependent: :destroy

    validate :exactly_one_parent_present

    private

    def exactly_one_parent_present
      return if plan_id.present? && subscription_id.blank?
      return if plan_id.blank? && subscription_id.present?

      errors.add(:base, "one_of_plan_or_subscription_required")
    end
  end
end

# == Schema Information
#
# Table name: entitlement_entitlements
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  deleted_at             :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  entitlement_feature_id :uuid             not null
#  organization_id        :uuid             not null
#  plan_id                :uuid
#  subscription_id        :uuid
#
# Indexes
#
#  idx_unique_feature_per_plan                               (entitlement_feature_id,plan_id) UNIQUE WHERE (deleted_at IS NULL)
#  idx_unique_feature_per_subscription                       (entitlement_feature_id,subscription_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_entitlement_entitlements_on_entitlement_feature_id  (entitlement_feature_id)
#  index_entitlement_entitlements_on_organization_id         (organization_id)
#  index_entitlement_entitlements_on_plan_id                 (plan_id)
#  index_entitlement_entitlements_on_subscription_id         (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (entitlement_feature_id => entitlement_features.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (plan_id => plans.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
