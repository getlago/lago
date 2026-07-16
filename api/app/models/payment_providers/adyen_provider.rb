# frozen_string_literal: true

module PaymentProviders
  class AdyenProvider < BaseProvider
    SUCCESS_REDIRECT_URL = "https://www.adyen.com/"

    WEBHOOKS_EVENTS = %w[AUTHORISATION CANCELLATION REFUND REFUND_FAILED CHARGEBACK].freeze
    IGNORED_WEBHOOK_EVENTS = %w[OFFER_CLOSED REPORT_AVAILABLE RECURRING_CONTRACT].freeze

    PROCESSING_STATUSES = %w[AuthorisedPending Received].freeze
    SUCCESS_STATUSES = %w[Authorised SentForSettle SettleScheduled Settled Refunded].freeze
    FAILED_STATUSES = %w[Cancelled CaptureFailed Error Expired Refused].freeze

    validates :api_key, :merchant_account, presence: true
    validates :success_redirect_url, adyen_url: true, allow_nil: true, length: {maximum: 1024}

    settings_accessors :live_prefix, :merchant_account
    secrets_accessors :api_key, :hmac_key

    def environment
      if Rails.env.production? && live_prefix.present?
        :live
      else
        :test
      end
    end

    def payment_type
      "adyen"
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
