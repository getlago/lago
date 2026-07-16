# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      module Payloads
        class Avalara < BasePayload
          def create_body
            [contact_body]
          end

          def update_body
            [contact_body]
          end

          private

          def contact_body
            shipping = customer.effective_shipping_address

            {
              "company_id" => integration.company_id&.to_i,
              "external_id" => customer.id,
              "name" => name,
              "address_line_1" => shipping[:address_line1],
              "city" => shipping[:city],
              "zip" => shipping[:zipcode],
              "country" => shipping[:country],
              "state" => shipping[:state],
              "tax_number" => customer.tax_identification_number
            }
          end

          def name
            return customer.name if customer.name.present?

            "#{customer.firstname} #{customer.lastname}".strip
          end
        end
      end
    end
  end
end
