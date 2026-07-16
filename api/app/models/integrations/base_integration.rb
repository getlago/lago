# frozen_string_literal: true

module Integrations
  class BaseIntegration < ApplicationRecord
    include PaperTrailTraceable
    include SecretsStorable
    include SettingsStorable

    self.table_name = "integrations"

    INTEGRATION_ACCOUNTING_TYPES = %w[Integrations::NetsuiteIntegration Integrations::XeroIntegration].freeze
    INTEGRATION_TAX_TYPES = %w[Integrations::AnrokIntegration Integrations::AvalaraIntegration].freeze

    belongs_to :organization

    has_many :integration_items, dependent: :destroy, foreign_key: :integration_id
    has_many :integration_resources, dependent: :destroy, foreign_key: :integration_id
    has_many :integration_mappings,
      class_name: "IntegrationMappings::BaseMapping",
      foreign_key: :integration_id,
      dependent: :destroy
    has_many :integration_collection_mappings,
      class_name: "IntegrationCollectionMappings::BaseCollectionMapping",
      foreign_key: :integration_id,
      dependent: :destroy
    has_many :integration_customers,
      class_name: "IntegrationCustomers::BaseCustomer",
      foreign_key: :integration_id,
      dependent: :destroy

    validates :code, uniqueness: {scope: :organization_id}
    validates :name, presence: true

    # Returns the short provider key, e.g. "netsuite", "anrok".
    def provider_key
      type.demodulize.delete_suffix("Integration").underscore
    end

    def self.integration_type(type)
      case type
      when "netsuite"
        "Integrations::NetsuiteIntegration"
      when "okta"
        "Integrations::OktaIntegration"
      when "anrok"
        "Integrations::AnrokIntegration"
      when "avalara"
        "Integrations::AvalaraIntegration"
      when "xero"
        "Integrations::XeroIntegration"
      when "hubspot"
        "Integrations::HubspotIntegration"
      when "salesforce"
        "Integrations::SalesforceIntegration"
      else
        raise(NotImplementedError)
      end
    end

    def external_id_key
      "id"
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
