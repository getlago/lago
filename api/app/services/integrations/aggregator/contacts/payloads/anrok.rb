# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      module Payloads
        class Anrok < BasePayload
          def create_body
            [
              {
                "name" => customer.display_name(prefer_legal_name: false),
                "city" => customer.city,
                "zip" => customer.zipcode,
                "country" => customer.country,
                "state" => customer.state,
                "email" => email,
                "phone" => phone
              }
            ]
          end

          def update_body
            [
              {
                "id" => integration_customer.external_customer_id,
                "name" => customer.display_name(prefer_legal_name: false),
                "city" => customer.city,
                "zip" => customer.zipcode,
                "country" => customer.country,
                "state" => customer.state,
                "email" => email,
                "phone" => phone
              }
            ]
          end
        end
      end
    end
  end
end
