# frozen_string_literal: true

module Integrations
  class OktaIntegration < BaseIntegration
    validates :client_secret, :client_id, :domain, :organization_name, presence: true
    validate :domain_uniqueness

    settings_accessors :client_id, :domain, :organization_name, :host
    secrets_accessors :client_secret

    def host
      get_from_settings("host") || "#{organization_name.downcase}.okta.com"
    end

    private

    def domain_uniqueness
      return if domain.blank?

      okta_integration = ::Integrations::OktaIntegration
        .where("settings->>'domain' IS NOT NULL")
        .where("settings->>'domain' = ?", domain)
        .where.not(id:)
        .exists?

      errors.add(:domain, "domain_not_unique") if okta_integration
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
