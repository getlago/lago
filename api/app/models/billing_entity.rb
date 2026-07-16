# frozen_string_literal: true

class BillingEntity < ApplicationRecord
  include PaperTrailTraceable
  include OrganizationTimezone
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at

  EMAIL_SETTINGS = [
    "invoice.finalized",
    "credit_note.created",
    "payment_receipt.created"
  ]

  EINVOICING_COUNTRIES = %w[FR DE].map(&:upcase)

  SUBSCRIPTION_INVOICE_ISSUING_DATE_ANCHORS = {
    current_period_end: "current_period_end",
    next_period_start: "next_period_start"
  }.freeze

  SUBSCRIPTION_INVOICE_ISSUING_DATE_ADJUSTMENTS = {
    keep_anchor: "keep_anchor",
    align_with_finalization_date: "align_with_finalization_date"
  }.freeze

  belongs_to :organization
  belongs_to :applied_dunning_campaign, class_name: "DunningCampaign", optional: true

  has_many :applied_taxes, class_name: "BillingEntity::AppliedTax", dependent: :destroy
  has_many :customers
  has_many :fees
  has_many :invoices
  has_many :pending_vies_checks
  has_many :payment_receipts
  has_many :applied_invoice_custom_sections,
    class_name: "BillingEntity::AppliedInvoiceCustomSection",
    dependent: :destroy
  has_many :integration_collection_mappings,
    class_name: "IntegrationCollectionMappings::BaseCollectionMapping",
    dependent: :destroy
  has_many :integration_mappings,
    class_name: "IntegrationMappings::BaseMapping",
    dependent: :destroy

  has_many :selected_invoice_custom_sections,
    through: :applied_invoice_custom_sections,
    source: :invoice_custom_section
  has_many :manual_selected_invoice_custom_sections,
    -> { where(section_type: :manual) },
    through: :applied_invoice_custom_sections,
    source: :invoice_custom_section
  has_many :system_generated_selected_invoice_custom_sections,
    -> { where(section_type: :system_generated) },
    through: :applied_invoice_custom_sections,
    source: :invoice_custom_section

  has_many :credit_notes, through: :invoices
  has_many :subscriptions, through: :customers
  has_many :taxes, through: :applied_taxes
  has_many :wallets, through: :customers
  has_many :wallet_transactions, through: :wallets

  has_many :activity_logs,
    -> { order(logged_at: :desc) },
    class_name: "Clickhouse::ActivityLog",
    as: :resource

  has_one_attached :logo

  DOCUMENT_NUMBERINGS = {
    per_customer: "per_customer",
    per_billing_entity: "per_billing_entity"
  }.freeze

  enum :document_numbering, DOCUMENT_NUMBERINGS

  enum :subscription_invoice_issuing_date_anchor, SUBSCRIPTION_INVOICE_ISSUING_DATE_ANCHORS, prefix: true, validate: true
  enum :subscription_invoice_issuing_date_adjustment, SUBSCRIPTION_INVOICE_ISSUING_DATE_ADJUSTMENTS, prefix: true, validate: true

  default_scope -> { kept }
  scope :active, -> { where(archived_at: nil).order(created_at: :asc) }

  validates :code,
    uniqueness: {
      conditions: -> { where(archived_at: nil, deleted_at: nil) },
      scope: :organization_id
    }
  validates :country, country_code: true, unless: -> { country.nil? }
  validates :default_currency, inclusion: {in: currency_list}
  validates :document_locale, language_code: true
  validates :email, email: true, if: :email?
  validates :invoice_footer, length: {maximum: 600}
  validates :document_number_prefix, length: {minimum: 1, maximum: 10}, allow_nil: true, on: :create
  validates :document_number_prefix, length: {minimum: 1, maximum: 10}, on: :update
  validates :invoice_grace_period, numericality: {greater_than_or_equal_to: 0}
  validates :net_payment_term, numericality: {greater_than_or_equal_to: 0}
  validates :logo,
    image: {authorized_content_type: %w[image/png image/jpg image/jpeg], max_size: 800.kilobytes},
    if: :logo?
  validates :name, presence: true
  validates :timezone, timezone: true
  validates :finalize_zero_amount_invoice, inclusion: {in: [true, false]}

  validate :validate_email_settings
  validate :validate_einvoicing

  normalizes :email, with: ->(email) { EmailSanitizer.call(email) }

  after_create :generate_document_number_prefix

  def country=(value)
    super(value&.upcase)
  end

  def document_number_prefix=(value)
    super(value&.upcase)
  end

  def logo_url
    return if logo.blank?

    Rails.application.routes.url_helpers.rails_blob_url(logo, host: ENV["LAGO_API_URL"])
  end

  def base64_logo
    return if logo.blank?

    logo.blob.open do |tempfile|
      data = tempfile.read
      Base64.encode64(data)
    end
  end

  def eu_vat_eligible?
    country && LagoEuVat::Rate.country_codes.include?(country)
  end

  def from_email_address
    return email if organization.from_email_enabled?

    ENV["LAGO_FROM_EMAIL"]
  end

  def reset_customers_last_dunning_campaign_attempt
    customers
      .falling_back_to_default_dunning_campaign
      .update_all( # rubocop:disable Rails/SkipsModelValidations
        dunning_currency_attempts: {},
        last_dunning_campaign_attempt: 0,
        last_dunning_campaign_attempt_at: nil
      )
  end

  def eligible_for_einvoicing?
    einvoicing && EINVOICING_COUNTRIES.include?(country.try(:upcase))
  end

  private

  def generate_document_number_prefix
    update!(document_number_prefix: "#{name.first(3).upcase}-#{id.last(4).upcase}") if document_number_prefix.nil?
  end

  def validate_email_settings
    return if email_settings.all? { |v| EMAIL_SETTINGS.include?(v) }

    errors.add(:email_settings, :unsupported_value)
  end

  def validate_einvoicing
    return unless einvoicing

    if country.nil?
      errors.add(:einvoicing, :country_must_be_present)
    elsif EINVOICING_COUNTRIES.exclude?(country.upcase)
      errors.add(:einvoicing, :country_not_supported)
    end
  end
end

# == Schema Information
#
# Table name: billing_entities
# Database name: primary
#
#  id                                           :uuid             not null, primary key
#  address_line1                                :string
#  address_line2                                :string
#  archived_at                                  :datetime
#  city                                         :string
#  code                                         :string           not null
#  country                                      :string
#  default_currency                             :string           default("USD"), not null
#  deleted_at                                   :datetime
#  document_locale                              :string           default("en"), not null
#  document_number_prefix                       :string
#  document_numbering                           :enum             default("per_customer"), not null
#  einvoicing                                   :boolean          default(FALSE), not null
#  email                                        :string
#  email_settings                               :string           default([]), not null, is an Array
#  eu_tax_management                            :boolean          default(FALSE)
#  finalize_zero_amount_invoice                 :boolean          default(TRUE), not null
#  invoice_footer                               :text
#  invoice_grace_period                         :integer          default(0), not null
#  legal_name                                   :string
#  legal_number                                 :string
#  logo                                         :string
#  name                                         :string           not null
#  net_payment_term                             :integer          default(0), not null
#  phone                                        :string
#  state                                        :string
#  subscription_invoice_issuing_date_adjustment :enum             default("align_with_finalization_date"), not null
#  subscription_invoice_issuing_date_anchor     :enum             default("next_period_start"), not null
#  tax_identification_number                    :string
#  timezone                                     :string           default("UTC"), not null
#  vat_rate                                     :float            default(0.0), not null
#  zipcode                                      :string
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  applied_dunning_campaign_id                  :uuid
#  organization_id                              :uuid             not null
#
# Indexes
#
#  index_billing_entities_on_applied_dunning_campaign_id  (applied_dunning_campaign_id)
#  index_billing_entities_on_code_and_organization_id     (code,organization_id) UNIQUE WHERE ((deleted_at IS NULL) AND (archived_at IS NULL))
#  index_billing_entities_on_organization_id              (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (applied_dunning_campaign_id => dunning_campaigns.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => organizations.id)
#
