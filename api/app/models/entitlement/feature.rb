# frozen_string_literal: true

module Entitlement
  class Feature < ApplicationRecord
    include Discard::Model

    self.discard_column = :deleted_at

    default_scope -> { kept }

    belongs_to :organization
    has_many :privileges, class_name: "Entitlement::Privilege", foreign_key: "entitlement_feature_id", dependent: :destroy
    has_many :entitlements, class_name: "Entitlement::Entitlement", foreign_key: "entitlement_feature_id", dependent: :destroy
    has_many :entitlement_values, through: :entitlements, source: :values, class_name: "Entitlement::EntitlementValue", dependent: :destroy
    has_many :plans, through: :entitlements

    validates :code, presence: true, length: {maximum: 255}
    validates :name, length: {maximum: 255}
    validates :description, length: {maximum: 600}

    attr_writer :subscriptions_count

    def self.ransackable_attributes(_auth_object = nil)
      %w[code name description]
    end

    def subscriptions_count
      return @subscriptions_count if defined?(@subscriptions_count)

      base_scope = Subscription.joins(:plan).where(status: [:active, :pending])
      base_scope.where(plan: plans).or(base_scope.where(plan: {parent: plans})).count
    end

    def self.preload_subscriptions_count(organization, features)
      subscriptions_count = SubscriptionsCountQuery.call(
        organization:,
        filters: {
          feature_ids: features.map(&:id)
        }
      )

      features.each do |feature|
        feature.subscriptions_count = subscriptions_count[feature.id] || 0
      end

      features
    end
  end
end

# == Schema Information
#
# Table name: entitlement_features
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  deleted_at      :datetime
#  description     :string
#  name            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  idx_features_code_unique_per_organization      (code,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_entitlement_features_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
