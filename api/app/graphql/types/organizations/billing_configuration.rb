# frozen_string_literal: true

module Types
  module Organizations
    class BillingConfiguration < Types::BaseObject
      graphql_name "OrganizationBillingConfiguration"

      field :document_locale, String
      field :id, ID, null: false
      field :invoice_footer, String
      field :invoice_grace_period, Integer, null: false
    end
  end
end
