# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::PremiumIntegrationTypeEnum do
  let(:premium_integration_types) do
    %w[
      beta_payment_authorization
      api_permissions
      auto_dunning
      hubspot
      netsuite
      okta
      progressive_billing
      lifetime_usage
      revenue_analytics
      revenue_share
      salesforce
      xero
      remove_branding_watermark
      manual_payments
      from_email
      issue_receipts
      preview
      avalara
      multi_entities_pro
      multi_entities_enterprise
      analytics_dashboards
      forecasted_usage
      projected_usage
      custom_roles
      events_targeting_wallets
      security_logs
      granular_lifetime_usage
      order_forms
      revenue_recognition
    ]
  end

  it "enumerizes the correct values" do
    expect(described_class.values.keys).to match_array(premium_integration_types)
  end
end
