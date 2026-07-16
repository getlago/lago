# frozen_string_literal: true

class Coupon < ApplicationRecord
  include PaperTrailTraceable
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization

  has_many :applied_coupons
  has_many :customers, through: :applied_coupons
  has_many :coupon_targets
  has_many :plans, through: :coupon_targets
  has_many :billable_metrics, through: :coupon_targets

  has_many :activity_logs,
    -> { order(logged_at: :desc) },
    class_name: "Clickhouse::ActivityLog",
    as: :resource

  STATUSES = [
    :active,
    :terminated
  ].freeze

  EXPIRATION_TYPES = [
    :no_expiration,
    :time_limit
  ].freeze

  COUPON_TYPES = [
    :fixed_amount,
    :percentage
  ].freeze

  FREQUENCIES = [
    :once,
    :recurring,
    :forever
  ].freeze

  enum :status, STATUSES, validate: true
  enum :expiration, EXPIRATION_TYPES, validate: true
  enum :coupon_type, COUPON_TYPES, validate: true
  enum :frequency, FREQUENCIES, validate: true

  monetize :amount_cents, disable_validation: true, allow_nil: true

  validates :name, presence: true
  validates :code, presence: true, uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :organization_id}

  validates :amount_cents, presence: true, if: :fixed_amount?
  validates :amount_cents, numericality: {greater_than: 0}, allow_nil: true

  validates :amount_currency, presence: true, if: :fixed_amount?
  validates :amount_currency, inclusion: {in: currency_list}, allow_nil: true

  validates :percentage_rate, presence: true, if: :percentage?

  validates :frequency_duration, presence: true, numericality: {greater_than: 0}, if: :recurring?

  validates :reusable, exclusion: [nil]

  default_scope -> { kept }
  scope :order_by_status_and_expiration,
    lambda {
      order(
        Arel.sql(
          [
            "coupons.status ASC",
            "coupons.expiration ASC",
            "coupons.expiration_at ASC"
          ].join(", ")
        )
      )
    }

  scope :expired, -> { where("coupons.expiration_at::timestamp(0) < ?", Time.current) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code]
  end

  def mark_as_terminated!(timestamp = Time.zone.now)
    self.terminated_at ||= timestamp
    terminated!
  end

  def parent_and_overriden_plans
    (plans + plans.map(&:children)).flatten
  end
end

# == Schema Information
#
# Table name: coupons
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  amount_cents             :bigint
#  amount_currency          :string
#  code                     :string           not null
#  coupon_type              :integer          default("fixed_amount"), not null
#  deleted_at               :datetime
#  description              :text
#  expiration               :integer          not null
#  expiration_at            :datetime
#  frequency                :integer          default("once"), not null
#  frequency_duration       :integer
#  limited_billable_metrics :boolean          default(FALSE), not null
#  limited_plans            :boolean          default(FALSE), not null
#  name                     :string           not null
#  percentage_rate          :decimal(10, 5)
#  reusable                 :boolean          default(TRUE), not null
#  status                   :integer          default("active"), not null
#  terminated_at            :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  organization_id          :uuid             not null
#
# Indexes
#
#  index_coupons_on_deleted_at                (deleted_at)
#  index_coupons_on_organization_id           (organization_id)
#  index_coupons_on_organization_id_and_code  (organization_id,code) UNIQUE WHERE (deleted_at IS NULL)
#
