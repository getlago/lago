# frozen_string_literal: true

class QuoteVersion < ApplicationRecord
  include Sequenced

  STATUSES = {
    draft: "draft",
    approved: "approved",
    voided: "voided"
  }.freeze

  VOID_REASONS = {
    manual: "manual",
    superseded: "superseded",
    cascade_of_expired: "cascade_of_expired",
    cascade_of_voided: "cascade_of_voided"
  }.freeze

  CASCADE_VOID_REASONS = VOID_REASONS.slice(:cascade_of_expired, :cascade_of_voided).freeze

  before_save :ensure_share_token

  belongs_to :organization
  belongs_to :quote
  has_one :order_form

  enum :status, STATUSES,
    default: :draft,
    validate: true
  enum :void_reason, VOID_REASONS,
    instance_methods: false,
    validate: {allow_nil: true}

  validates :share_token,
    on: :update,
    presence: true,
    if: -> { draft? || approved? }

  validates :void_reason, :voided_at,
    presence: true,
    if: -> { voided? }

  validates :approved_at,
    presence: true,
    if: -> { approved? }

  sequenced(
    scope: ->(quote_version) { quote_version.quote.versions },
    lock_key: ->(quote_version) { quote_version.quote_id }
  )

  def version = sequential_id

  private

  def ensure_share_token
    return if voided?

    self.share_token ||= SecureRandom.uuid
  end
end

# == Schema Information
#
# Table name: quote_versions
# Database name: primary
#
#  id                :uuid             not null, primary key
#  approved_at       :datetime
#  billing_items     :jsonb
#  content           :text
#  currency          :string
#  end_date          :date
#  mention_variables :jsonb
#  share_token       :string
#  start_date        :date
#  status            :enum             default("draft"), not null
#  void_reason       :enum
#  voided_at         :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  organization_id   :uuid             not null
#  quote_id          :uuid             not null
#  sequential_id     :integer          not null
#
# Indexes
#
#  index_quote_versions_on_organization_id             (organization_id)
#  index_quote_versions_on_quote_id                    (quote_id)
#  index_unique_quote_versions_on_quote_active_status  (quote_id) UNIQUE WHERE (status = ANY (ARRAY['draft'::quote_status, 'approved'::quote_status]))
#  index_unique_quote_versions_on_quote_sequential_id  (quote_id,sequential_id) UNIQUE
#  index_unique_quote_versions_on_share_token          (share_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (quote_id => quotes.id)
#
