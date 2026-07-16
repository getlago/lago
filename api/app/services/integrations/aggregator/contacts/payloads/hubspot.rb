# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      module Payloads
        class Hubspot < BasePayload
          def create_body
            {
              "properties" => {
                "lago_customer_id" => customer.id,
                "lago_customer_external_id" => customer.external_id,
                "lago_billing_email" => customer.email,
                "lago_customer_link" => customer_url
              }.merge(
                {
                  "email" => customer.email,
                  "firstname" => customer.firstname,
                  "lastname" => customer.lastname,
                  "phone" => customer.phone,
                  "company" => customer.legal_name,
                  "website" => clean_url(customer.url)
                }.compact_blank
              )
            }
          end

          def update_body
            {
              "contactId" => integration_customer.external_customer_id,
              "input" => {
                "properties" => {
                  "email" => customer.email,
                  "firstname" => customer.firstname,
                  "lastname" => customer.lastname,
                  "phone" => customer.phone,
                  "company" => customer.legal_name,
                  "website" => clean_url(customer.url)
                }.compact_blank
              }
            }
          end
        end
      end
    end
  end
end
