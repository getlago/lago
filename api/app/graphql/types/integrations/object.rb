# frozen_string_literal: true

module Types
  module Integrations
    class Object < Types::BaseUnion
      graphql_name "Integration"

      possible_types Types::Integrations::Netsuite,
        Types::Integrations::Okta,
        Types::Integrations::Anrok,
        Types::Integrations::Avalara,
        Types::Integrations::Xero,
        Types::Integrations::Hubspot,
        Types::Integrations::Salesforce

      def self.resolve_type(object, _context)
        case object.class.to_s
        when "Integrations::NetsuiteIntegration"
          Types::Integrations::Netsuite
        when "Integrations::OktaIntegration"
          Types::Integrations::Okta
        when "Integrations::AnrokIntegration"
          Types::Integrations::Anrok
        when "Integrations::AvalaraIntegration"
          Types::Integrations::Avalara
        when "Integrations::XeroIntegration"
          Types::Integrations::Xero
        when "Integrations::HubspotIntegration"
          Types::Integrations::Hubspot
        when "Integrations::SalesforceIntegration"
          Types::Integrations::Salesforce
        else
          raise "Unexpected integration type: #{object.inspect}"
        end
      end
    end
  end
end
