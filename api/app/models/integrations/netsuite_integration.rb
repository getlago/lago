# frozen_string_literal: true

module Integrations
  class NetsuiteIntegration < BaseIntegration
    validates :connection_id, :client_secret, :client_id, :account_id, :script_endpoint_url, presence: true

    settings_accessors :client_id,
      :legacy_script,
      :sync_credit_notes,
      :sync_invoices,
      :sync_payments,
      :script_endpoint_url,
      :token_id
    secrets_accessors :connection_id, :client_secret, :token_secret

    def account_id=(value)
      push_to_settings(key: "account_id", value: value&.downcase&.strip&.split(" ")&.join("-"))
    end

    def account_id
      get_from_settings("account_id")
    end
  end
end

# == Schema Information
#
# Table name: integrations
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
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
#  index_integrations_on_code_and_organization_id  (code,organization_id) UNIQUE
#  index_integrations_on_organization_id           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
