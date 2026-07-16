# frozen_string_literal: true

module Types
  module Integrations
    class Okta < Types::BaseObject
      graphql_name "OktaIntegration"

      field :client_id, String, null: true
      field :client_secret, ObfuscatedStringType, null: true
      field :code, String, null: false
      field :domain, String, null: false
      field :host, String, null: true
      field :id, ID, null: false
      field :name, String, null: false
      field :organization_name, String, null: false
    end
  end
end
