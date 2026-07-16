# frozen_string_literal: true

module Integrations
  class XeroIntegration < BaseIntegration
    validates :connection_id, presence: true

    settings_accessors :sync_credit_notes, :sync_invoices, :sync_payments
    secrets_accessors :connection_id

    def external_id_key
      "item_code"
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
