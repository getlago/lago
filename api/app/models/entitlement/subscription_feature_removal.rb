# frozen_string_literal: true

module Entitlement
  class SubscriptionFeatureRemoval < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at

    default_scope -> { kept }

    belongs_to :organization
    belongs_to :subscription
    belongs_to :feature, optional: true, class_name: "Entitlement::Feature", foreign_key: :entitlement_feature_id
    belongs_to :privilege, optional: true, class_name: "Entitlement::Privilege", foreign_key: :entitlement_privilege_id
  end
end

# == Schema Information
#
# Table name: entitlement_subscription_feature_removals
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  deleted_at               :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  entitlement_feature_id   :uuid
#  entitlement_privilege_id :uuid
#  organization_id          :uuid             not null
#  subscription_id          :uuid             not null
#
# Indexes
#
#  idx_on_entitlement_feature_id_821ae72311                       (entitlement_feature_id)
#  idx_on_entitlement_privilege_id_9946ccf514                     (entitlement_privilege_id)
#  idx_on_organization_id_7020c3c43a                              (organization_id)
#  idx_on_subscription_id_295edd8bb3                              (subscription_id)
#  idx_unique_feature_removal_per_subscription                    (subscription_id,entitlement_feature_id) UNIQUE WHERE (deleted_at IS NULL)
#  idx_unique_privilege_removal_per_subscription                  (subscription_id,entitlement_privilege_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_entitlement_subscription_feature_removals_on_deleted_at  (deleted_at)
#
# Foreign Keys
#
#  fk_rails_...  (entitlement_feature_id => entitlement_features.id)
#  fk_rails_...  (entitlement_privilege_id => entitlement_privileges.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
