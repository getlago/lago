# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      module Payloads
        class BasePayload < Integrations::Aggregator::BasePayload
          def initialize(integration:, customer:, integration_customer: nil, subsidiary_id: nil)
            super(integration:, billing_entity: customer.billing_entity)

            @customer = customer
            @integration_customer = integration_customer
            @subsidiary_id = subsidiary_id
          end

          def create_body
            [
              {
                "name" => customer.name,
                "city" => customer.city,
                "zip" => customer.zipcode,
                "country" => customer.country,
                "state" => customer.state,
                "email" => email,
                "phone" => phone
              }.merge(contact_names)
            ]
          end

          def update_body
            [
              {
                "id" => integration_customer.external_customer_id,
                "name" => customer.name,
                "city" => customer.city,
                "zip" => customer.zipcode,
                "country" => customer.country,
                "state" => customer.state,
                "email" => email,
                "phone" => phone
              }.merge(contact_names)
            ]
          end

          private

          attr_reader :customer, :integration_customer, :subsidiary_id

          def contact_names
            {"firstname" => customer.firstname, "lastname" => customer.lastname}.compact_blank
          end

          def email
            customer.email.to_s.split(",").first&.strip
          end

          def phone
            customer.phone.to_s.split(",").first&.strip
          end

          def customer_url
            url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

            URI.join(url, "/#{customer.organization.slug}/customer/", customer.id).to_s
          end

          def clean_url(url)
            url = "http://#{url}" unless /\Ahttps?:\/\//.match?(url)

            uri = URI.parse(url.to_s)
            uri.host
          end
        end
      end
    end
  end
end
