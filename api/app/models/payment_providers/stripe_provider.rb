# frozen_string_literal: true

module PaymentProviders
  class StripeProvider < BaseProvider
    AMOUNT_TOO_SMALL_ERROR_CODE = "amount_too_small"
    NEED_3DS_ERROR_CODE = "authentication_required"

    StripePayment = Data.define(:id, :status, :metadata, :error_code)

    SUCCESS_REDIRECT_URL = "https://stripe.com/"

    # NOTE: find the complete list of event types at https://stripe.com/docs/api/events/types
    WEBHOOKS_EVENTS = %w[
      setup_intent.succeeded
      payment_intent.payment_failed
      payment_intent.succeeded
      payment_intent.canceled
      payment_method.detached
      charge.refund.updated
      customer.updated
      charge.dispute.closed
    ].freeze

    PROCESSING_STATUSES = %w[
      processing
      requires_capture
      requires_action
      requires_confirmation
    ].freeze
    SUCCESS_STATUSES = %w[succeeded].freeze
    FAILED_STATUSES = %w[canceled requires_payment_method].freeze
    SUPPORTED_EU_BANK_TRANSFER_COUNTRIES = %w[BE DE ES FR IE NL].freeze

    validates :secret_key, presence: true
    validates :success_redirect_url, url: true, allow_nil: true, length: {maximum: 1024}

    settings_accessors :webhook_id
    secrets_accessors :secret_key
    settings_accessors :supports_3ds

    def payment_type
      "stripe"
    end
  end
end

# == Schema Information
#
# Table name: payment_providers
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  deleted_at      :datetime
#  name            :string           not null
#  secrets         :string
#  settings        :jsonb            not null
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_payment_providers_on_code_and_organization_id  (code,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_providers_on_organization_id           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
