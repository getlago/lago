# frozen_string_literal: true

FactoryBot.define do
  factory :netsuite_integration, class: "Integrations::NetsuiteIntegration" do
    organization
    type { "Integrations::NetsuiteIntegration" }
    code { "netsuite_#{SecureRandom.uuid}" }
    name { "Accounting integration 1" }

    secrets do
      {connection_id: SecureRandom.uuid, client_secret: SecureRandom.uuid}.to_json
    end

    settings do
      {account_id: "acc_12345", client_id: "cli_12345", script_endpoint_url: Faker::Internet.url, legacy_script: false}
    end
  end

  factory :okta_integration, class: "Integrations::OktaIntegration" do
    organization
    type { "Integrations::OktaIntegration" }
    code { "okta" }
    name { "Okta Integration" }

    settings do
      {client_id: SecureRandom.uuid, domain: "foo.test", organization_name: "Foobar"}
    end

    secrets do
      {client_secret: SecureRandom.uuid}.to_json
    end
  end

  factory :anrok_integration, class: "Integrations::AnrokIntegration" do
    organization
    type { "Integrations::AnrokIntegration" }
    code { "anrok" }
    name { "Anrok Integration" }

    secrets do
      {connection_id: SecureRandom.uuid, api_key: SecureRandom.uuid}.to_json
    end
  end

  factory :avalara_integration, class: "Integrations::AvalaraIntegration" do
    organization
    type { "Integrations::AvalaraIntegration" }
    code { "avalara" }
    name { "Avalara Integration" }

    settings do
      {account_id: SecureRandom.uuid, company_code: "DEFAULT"}
    end

    secrets do
      {connection_id: SecureRandom.uuid, license_key: SecureRandom.uuid}.to_json
    end
  end

  factory :xero_integration, class: "Integrations::XeroIntegration" do
    organization
    type { "Integrations::XeroIntegration" }
    code { "xero" }
    name { "Xero Integration" }

    secrets do
      {connection_id: SecureRandom.uuid}.to_json
    end
  end

  factory :hubspot_integration, class: "Integrations::HubspotIntegration" do
    organization
    type { "Integrations::HubspotIntegration" }
    code { "hubspot" }
    name { "Hubspot Integration" }

    settings do
      {
        default_targeted_object: "companies",
        sync_subscriptions: true,
        sync_invoices: true,
        subscriptions_object_type_id: Faker::Number.number(digits: 2),
        invoices_object_type_id: Faker::Number.number(digits: 2),
        companies_properties_version: 1,
        contacts_properties_version: 1,
        subscriptions_properties_version: 1,
        invoices_properties_version: 1
      }
    end

    secrets do
      {connection_id: SecureRandom.uuid}.to_json
    end
  end

  factory :salesforce_integration, class: "Integrations::SalesforceIntegration" do
    organization
    type { "Integrations::SalesforceIntegration" }
    code { "salesforce" }
    name { "Salesforce Integration" }

    settings do
      {instance_id: SecureRandom.uuid}
    end
  end
end
