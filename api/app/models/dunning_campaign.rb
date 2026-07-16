# frozen_string_literal: true

class DunningCampaign < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at
  self.ignored_columns += %w[applied_to_organization]

  ORDERS = %w[name code].freeze

  belongs_to :organization

  has_many :thresholds, class_name: "DunningCampaignThreshold", dependent: :destroy
  has_many :customers, foreign_key: :applied_dunning_campaign_id, dependent: :nullify
  has_many :billing_entities, foreign_key: :applied_dunning_campaign_id
  has_many :payment_requests, dependent: :nullify

  accepts_nested_attributes_for :thresholds

  validates :name, presence: true
  validates :bcc_emails, email_array: true
  validates :days_between_attempts, numericality: {greater_than: 0}
  validates :max_attempts, numericality: {greater_than: 0}
  validates :code,
    uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :organization_id},
    unless: :deleted_at

  default_scope -> { kept }
  scope :applied_to_organization, -> { where(applied_to_organization: true) }
  scope :with_currency_threshold, ->(currencies) {
    joins(:thresholds)
      .where(dunning_campaign_thresholds: {currency: currencies})
      .distinct
  }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code]
  end

  def reset_customers_last_attempt
    # NOTE: Reset last attempt on customers with the campaign applied explicitly
    customers.update_all( # rubocop:disable Rails/SkipsModelValidations
      dunning_currency_attempts: {},
      last_dunning_campaign_attempt: 0,
      last_dunning_campaign_attempt_at: nil
    )

    # NOTE: Reset last attempt on customers falling back to the billing_entity campaign
    billing_entities.includes(:customers).map(&:reset_customers_last_dunning_campaign_attempt)
  end
end

# == Schema Information
#
# Table name: dunning_campaigns
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  bcc_emails            :string           default([]), is an Array
#  code                  :string           not null
#  days_between_attempts :integer          default(1), not null
#  deleted_at            :datetime
#  description           :text
#  max_attempts          :integer          default(1), not null
#  name                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  organization_id       :uuid             not null
#
# Indexes
#
#  index_dunning_campaigns_on_deleted_at                  (deleted_at)
#  index_dunning_campaigns_on_organization_id             (organization_id)
#  index_dunning_campaigns_on_organization_id_and_code    (organization_id,code) UNIQUE WHERE (deleted_at IS NULL)
#  index_unique_applied_to_organization_per_organization  (organization_id) UNIQUE WHERE ((applied_to_organization = true) AND (deleted_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
