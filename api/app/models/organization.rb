# frozen_string_literal: true

class Organization < ApplicationRecord
  include PaperTrailTraceable
  include OrganizationTimezone
  include Currencies
  include Organizations::AuthenticationMethods
  include HasFeatureFlags
  include Organizations::Sluggable

  self.ignored_columns += [:clickhouse_aggregation]

  EMAIL_SETTINGS = [
    "invoice.finalized",
    "credit_note.created",
    "payment_receipt.created"
  ].freeze

  MULTI_ENTITIES_MAX = {
    default: 1,
    pro: 2,
    enterprise: Float::INFINITY
  }.freeze

  has_many :activity_logs, class_name: "Clickhouse::ActivityLog"
  has_many :ai_conversations
  has_many :api_logs, class_name: "Clickhouse::ApiLog"
  has_many :api_keys
  has_many :security_logs, class_name: "Clickhouse::SecurityLog"
  has_many :billing_entities, -> { active }
  has_many :all_billing_entities, class_name: "BillingEntity"
  has_many :memberships
  has_many :active_memberships, -> { active }, class_name: "Membership"
  has_many :users, through: :memberships

  # TODO: Remove in favor of admins through admin_membership_roles
  has_many :admins_memberships, -> { active.admins }, class_name: "Membership"
  has_many :admins, through: :admins_memberships, source: :user
  # New way to access admin users
  has_many :membership_roles, through: :active_memberships
  has_many :admin_membership_roles, -> { admins }, through: :active_memberships, source: :membership_roles
  has_many :admin_memberships, through: :admin_membership_roles, source: :membership
  has_many :admin_users, through: :admin_memberships, source: :user

  has_many :billable_metrics
  has_many :plans
  has_many :charges
  has_many :fixed_charges
  has_many :charge_filters
  has_many :pricing_units
  has_many :customers
  has_many :subscriptions
  has_many :activation_rules, class_name: "Subscription::ActivationRule"
  has_many :invoices
  has_many :credit_notes
  has_many :fees
  has_many :events
  has_many :coupons
  has_many :applied_coupons
  has_many :add_ons
  has_many :daily_usages
  has_many :invites
  has_many :integrations, class_name: "Integrations::BaseIntegration"
  has_many :payment_methods
  has_many :payment_providers, class_name: "PaymentProviders::BaseProvider"
  has_many :payment_receipts
  has_many :payment_requests
  has_many :taxes
  has_many :wallets
  has_many :wallet_transactions
  has_many :webhook_endpoints
  has_many :webhooks
  has_many :cached_aggregations
  has_many :data_exports
  has_many :error_details
  has_many :dunning_campaigns
  has_many :roles
  has_many :quotes
  has_many :quote_versions
  has_many :order_forms
  has_many :orders
  has_many :activity_logs, class_name: "Clickhouse::ActivityLog"
  has_many :features, class_name: "Entitlement::Feature"
  has_many :privileges, class_name: "Entitlement::Privilege"
  has_many :entitlements, class_name: "Entitlement::Entitlement"
  has_many :entitlement_values, class_name: "Entitlement::EntitlementValue"
  has_many :subscription_feature_removals, class_name: "Entitlement::SubscriptionFeatureRemoval"

  has_many :subscription_activities, class_name: "UsageMonitoring::SubscriptionActivity"
  has_many :alerts, class_name: "UsageMonitoring::Alert"
  has_many :triggered_alerts, class_name: "UsageMonitoring::TriggeredAlert"
  has_many :pending_vies_checks

  has_many :stripe_payment_providers, class_name: "PaymentProviders::StripeProvider"
  has_many :gocardless_payment_providers, class_name: "PaymentProviders::GocardlessProvider"
  has_many :cashfree_payment_providers, class_name: "PaymentProviders::CashfreeProvider"
  has_many :adyen_payment_providers, class_name: "PaymentProviders::AdyenProvider"

  has_many :hubspot_integrations, class_name: "Integrations::HubspotIntegration"
  has_many :netsuite_integrations, class_name: "Integrations::NetsuiteIntegration"
  has_many :xero_integrations, class_name: "Integrations::XeroIntegration"
  has_one :salesforce_integration, class_name: "Integrations::SalesforceIntegration"

  has_one :applied_dunning_campaign, -> { where(applied_to_organization: true) }, class_name: "DunningCampaign"
  has_one :default_billing_entity, -> { active.order(created_at: :asc) }, class_name: "BillingEntity"
  has_one :enriched_store_migration

  has_many :invoice_custom_sections
  has_many :manual_invoice_custom_sections, -> { where(section_type: "manual") }, class_name: "InvoiceCustomSection"
  has_many :system_generated_invoice_custom_sections, -> { where(section_type: "system_generated") }, class_name: "InvoiceCustomSection"

  has_one_attached :logo

  EVENTS_STORES = {
    clickhouse: "clickhouse",
    postgres: "postgres"
  }.freeze

  DOCUMENT_NUMBERINGS = [
    :per_customer,
    :per_organization
  ].freeze

  NON_PREMIUM_INTEGRATIONS = %w[
    anrok
  ].freeze

  PREMIUM_INTEGRATIONS = %w[
    beta_payment_authorization
    netsuite
    okta
    avalara
    xero
    progressive_billing
    lifetime_usage
    hubspot
    auto_dunning
    revenue_analytics
    salesforce
    api_permissions
    revenue_share
    remove_branding_watermark
    manual_payments
    from_email
    issue_receipts
    preview
    multi_entities_pro
    multi_entities_enterprise
    analytics_dashboards
    forecasted_usage
    projected_usage
    custom_roles
    events_targeting_wallets
    security_logs
    granular_lifetime_usage
    order_forms
    revenue_recognition
  ].freeze

  SECURITY_LOGS_RETENTION_DAYS = 90

  INTEGRATIONS = (NON_PREMIUM_INTEGRATIONS + PREMIUM_INTEGRATIONS).freeze

  enum :document_numbering, DOCUMENT_NUMBERINGS, validate: true

  validates :country, country_code: true, unless: -> { country.nil? }
  validates :default_currency, inclusion: {in: currency_list}
  validates :document_locale, language_code: true
  validates :email, email: true, if: :email?
  validates :invoice_footer, length: {maximum: 600}
  validates :document_number_prefix, length: {minimum: 1, maximum: 10}, on: :update
  validates :invoice_grace_period, numericality: {greater_than_or_equal_to: 0}
  validates :net_payment_term, numericality: {greater_than_or_equal_to: 0}
  validates :logo,
    image: {authorized_content_type: %w[image/png image/jpg image/jpeg], max_size: 800.kilobytes},
    if: :logo?
  validates :name, presence: true
  validates :timezone, timezone: true
  validates :webhook_url, url: true, allow_nil: true
  validates :finalize_zero_amount_invoice, inclusion: {in: [true, false]}
  validates :hmac_key, uniqueness: true
  validates :hmac_key, presence: true, on: :update

  validate :validate_premium_integrations
  validate :validate_email_settings

  normalizes :email, with: ->(email) { EmailSanitizer.call(email) }

  before_create :set_hmac_key
  after_create :generate_document_number_prefix

  scope :with_any_premium_integrations, ->(names) { where("premium_integrations && ARRAY[?]::varchar[]", Array.wrap(names)) }

  PREMIUM_INTEGRATIONS.each do |premium_integration|
    scope "with_#{premium_integration}_support", -> { where("? = ANY(premium_integrations)", premium_integration) }

    define_method("#{premium_integration}_enabled?") do
      License.premium? && premium_integrations.include?(premium_integration)
    end
  end

  def using_lifetime_usage?
    lifetime_usage_enabled? || progressive_billing_enabled?
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

  def payment_provider(provider)
    case provider
    when "stripe"
      stripe_payment_provider
    when "gocardless"
      gocardless_payment_provider
    when "cashfree"
      cashfree_payment_provider
    when "adyen"
      adyen_payment_provider
    end
  end

  def document_number_prefix=(value)
    super(value&.upcase)
  end

  def from_email_address
    return email if from_email_enabled?

    ENV["LAGO_FROM_EMAIL"]
  end

  def can_create_billing_entity?
    remaining_billing_entities > 0
  end

  def failed_tax_invoices_count
    invoices.where(status: :failed).joins(:error_details).where(error_details: {error_code: "tax_error"}).count
  end

  # This field used to be on organization, but as we're migrating this data to the billing entity, it should be taken from the billing_entity
  def default_currency
    return default_billing_entity.default_currency if default_billing_entity

    super
  end

  # This field used to be on organization, but as we're migrating this data to the billing entity, it should be taken from the billing_entity
  def timezone
    return default_billing_entity.timezone if default_billing_entity

    super
  end

  def postgres_events_store?
    !clickhouse_events_store?
  end

  def events_store
    clickhouse_events_store? ? EVENTS_STORES[:clickhouse] : EVENTS_STORES[:postgres]
  end

  # This is added to have a common interface for all organization-related models to access the organization.
  def organization
    self
  end

  def maximum_wallets_per_customer
    max_wallets if events_targeting_wallets_enabled?
  end

  private

  # NOTE: After creating an organization, default document_number_prefix needs to be generated.
  # Example of expected format is ORG-4321
  def generate_document_number_prefix
    update!(document_number_prefix: "#{name.first(3).upcase}-#{id.last(4).upcase}")
  end

  def validate_email_settings
    return if email_settings.all? { |v| EMAIL_SETTINGS.include?(v) }

    errors.add(:email_settings, :unsupported_value)
  end

  def validate_premium_integrations
    return if premium_integrations.all? { |v| PREMIUM_INTEGRATIONS.include?(v) }

    errors.add(:premium_integrations, :inclusion, value: premium_integrations)
  end

  def set_hmac_key
    loop do
      self.hmac_key = SecureRandom.uuid
      break unless self.class.exists?(hmac_key:)
    end
  end

  def remaining_billing_entities
    return MULTI_ENTITIES_MAX[:enterprise] if multi_entities_enterprise_enabled?
    return MULTI_ENTITIES_MAX[:pro] - billing_entities.active.count if multi_entities_pro_enabled?

    MULTI_ENTITIES_MAX[:default] - billing_entities.active.count
  end
end

# == Schema Information
#
# Table name: organizations
# Database name: primary
#
#  id                               :uuid             not null, primary key
#  address_line1                    :string
#  address_line2                    :string
#  api_key                          :string
#  audit_logs_period                :integer          default(30)
#  authentication_methods           :string           default(["email_password", "google_oauth"]), not null, is an Array
#  city                             :string
#  clickhouse_deduplication_enabled :boolean          default(FALSE), not null
#  clickhouse_events_store          :boolean          default(FALSE), not null
#  country                          :string
#  custom_aggregation               :boolean          default(FALSE)
#  default_currency                 :string           default("USD"), not null
#  document_locale                  :string           default("en"), not null
#  document_number_prefix           :string
#  document_numbering               :integer          default("per_customer"), not null
#  email                            :string
#  email_settings                   :string           default([]), not null, is an Array
#  eu_tax_management                :boolean          default(FALSE)
#  feature_flags                    :string           default([]), not null, is an Array
#  finalize_zero_amount_invoice     :boolean          default(TRUE), not null
#  hmac_key                         :string           not null
#  invoice_footer                   :text
#  invoice_grace_period             :integer          default(0), not null
#  legal_name                       :string
#  legal_number                     :string
#  logo                             :string
#  max_wallets                      :integer
#  name                             :string           not null
#  net_payment_term                 :integer          default(0), not null
#  pre_filter_events                :boolean          default(FALSE), not null
#  premium_integrations             :string           default([]), not null, is an Array
#  slug                             :string           not null
#  state                            :string
#  tax_identification_number        :string
#  timezone                         :string           default("UTC"), not null
#  vat_rate                         :float            default(0.0), not null
#  webhook_url                      :string
#  zipcode                          :string
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_organizations_on_api_key   (api_key) UNIQUE
#  index_organizations_on_hmac_key  (hmac_key) UNIQUE
#  index_organizations_on_slug      (slug) UNIQUE
#
