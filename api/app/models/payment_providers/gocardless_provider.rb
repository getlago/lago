# frozen_string_literal: true

module PaymentProviders
  class GocardlessProvider < BaseProvider
    SUCCESS_REDIRECT_URL = "https://gocardless.com/"

    PROCESSING_STATUSES = %w[pending_customer_approval pending_submission submitted confirmed].freeze
    SUCCESS_STATUSES = %w[paid_out].freeze
    FAILED_STATUSES = %w[cancelled customer_approval_denied failed charged_back].freeze

    validates :access_token, presence: true
    validates :success_redirect_url, url: true, allow_nil: true, length: {maximum: 1024}

    secrets_accessors :access_token

    def self.auth_site
      if Rails.env.production?
        "https://connect.gocardless.com"
      else
        "https://connect-sandbox.gocardless.com"
      end
    end

    def environment
      if Rails.env.production?
        :live
      else
        :sandbox
      end
    end

    def payment_type
      "gocardless"
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
