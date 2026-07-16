# frozen_string_literal: true

module PaymentProviders
  class FlutterwaveProvider < BaseProvider
    FlutterwavePayment = Data.define(:id, :status, :metadata)

    SUCCESS_REDIRECT_URL = "https://www.flutterwave.com/ng"
    API_URL = "https://api.flutterwave.com/v3"

    PROCESSING_STATUSES = %w[pending].freeze
    SUCCESS_STATUSES = %w[successful].freeze
    FAILED_STATUSES = %w[failed cancelled].freeze
    validates :secret_key, presence: true
    validates :success_redirect_url, url: true, allow_nil: true, length: {maximum: 1024}

    secrets_accessors :secret_key, :webhook_secret

    before_create :generate_webhook_secret

    def payment_type
      "flutterwave"
    end

    def api_url
      API_URL
    end

    private

    def generate_webhook_secret
      self.webhook_secret = SecureRandom.hex(32) if webhook_secret.blank?
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
