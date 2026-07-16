# frozen_string_literal: true

module Integrations
  class HubspotIntegration < BaseIntegration
    validates :connection_id, :default_targeted_object, presence: true

    settings_accessors :default_targeted_object, :sync_subscriptions, :sync_invoices, :subscriptions_object_type_id,
      :invoices_object_type_id, :companies_properties_version, :contacts_properties_version,
      :subscriptions_properties_version, :invoices_properties_version, :portal_id
    secrets_accessors :connection_id

    TARGETED_OBJECTS = %w[companies contacts].freeze

    def companies_object_type_id
      "0-2"
    end

    def contacts_object_type_id
      "0-1"
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
