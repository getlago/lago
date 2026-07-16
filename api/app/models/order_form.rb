# frozen_string_literal: true

class OrderForm < ApplicationRecord
  include Sequenced

  STATUSES = {
    generated: "generated",
    signed: "signed",
    expired: "expired",
    voided: "voided"
  }.freeze

  VOID_REASONS = {
    manual: "manual",
    expired: "expired",
    invalid: "invalid"
  }.freeze

  SIGNED_DOCUMENT_CONTENT_TYPES = %w[application/pdf image/jpeg image/png].freeze
  SIGNED_DOCUMENT_MAX_SIZE = 10.megabytes

  before_save :ensure_number

  belongs_to :organization
  belongs_to :customer
  belongs_to :quote_version
  has_one :quote, through: :quote_version
  has_one :order

  has_one_attached :signed_document

  enum :status, STATUSES,
    default: :generated,
    validate: true
  enum :void_reason, VOID_REASONS,
    instance_methods: false,
    validate: {allow_nil: true}

  validates :void_reason, presence: true, if: :voided?
  validates :signed_document,
    content_type: SIGNED_DOCUMENT_CONTENT_TYPES,
    size: {less_than: SIGNED_DOCUMENT_MAX_SIZE}

  scope :expirable, -> do
    at_time_zone = Utils::Timezone.at_time_zone_sql

    generated
      .joins(customer: :billing_entity)
      .where.not(expires_at: nil)
      .where("DATE(order_forms.expires_at#{at_time_zone}) <= DATE(?#{at_time_zone})", Time.current)
  end

  sequenced(
    scope: ->(order_form) { order_form.organization.order_forms },
    lock_key: ->(order_form) { order_form.organization_id }
  )

  def self.ransackable_attributes(_ = nil)
    %w[number]
  end

  def signed_document_url
    return if signed_document.blank?
    return unless signed_document.blob.persisted?

    Rails.application.routes.url_helpers.rails_blob_url(signed_document, host: ENV["LAGO_API_URL"])
  end

  private

  def ensure_number
    return if number.present?
    return if sequential_id.blank?

    time = created_at || Time.current
    formatted_sequential_id = format("%04d", sequential_id)
    self.number = "OF-#{time.strftime("%Y")}-#{formatted_sequential_id}"
  end
end

# == Schema Information
#
# Table name: order_forms
# Database name: primary
#
#  id               :uuid             not null, primary key
#  expires_at       :datetime
#  number           :string           not null
#  signed_at        :datetime
#  status           :enum             default("generated"), not null
#  void_reason      :enum
#  voided_at        :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  customer_id      :uuid             not null
#  organization_id  :uuid             not null
#  quote_version_id :uuid             not null
#  sequential_id    :integer          not null
#
# Indexes
#
#  index_order_forms_on_customer_id                        (customer_id)
#  index_order_forms_on_organization_id_and_created_at     (organization_id,created_at)
#  index_order_forms_on_organization_id_and_expires_at     (organization_id,expires_at)
#  index_order_forms_on_organization_id_and_status         (organization_id,status)
#  index_order_forms_on_quote_version_id                   (quote_version_id) UNIQUE
#  index_unique_order_forms_on_organization_number         (organization_id,number) UNIQUE
#  index_unique_order_forms_on_organization_sequential_id  (organization_id,sequential_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (quote_version_id => quote_versions.id)
#
