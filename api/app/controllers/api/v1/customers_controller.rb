# frozen_string_literal: true

module Api
  module V1
    class CustomersController < Api::BaseController
      def create
        result = ::Customers::UpsertFromApiService.call(
          organization: current_organization,
          params: create_params.to_h.deep_symbolize_keys
        )

        if result.success?
          render_customer(result.customer)
        else
          render_error_response(result)
        end
      end

      def portal_url
        customer = current_organization.customers.find_by(external_id: params[:customer_external_id])

        result = ::CustomerPortal::GenerateUrlService.call(customer:)

        if result.success?
          render(
            json: {
              customer: {
                portal_url: result.url
              }
            }
          )
        else
          render_error_response(result)
        end
      end

      def index
        filter_params = params.permit(
          :search_term,
          :has_tax_identification_number,
          :has_customer_type,
          :customer_type,
          :external_id,
          currencies: [],
          countries: [],
          states: [],
          zipcodes: [],
          billing_entity_codes: [],
          account_type: [],
          metadata: {}
        )
        search_term = filter_params.delete(:search_term)
        billing_entity_codes = filter_params.delete(:billing_entity_codes)
        if billing_entity_codes.present?
          billing_entities = current_organization.all_billing_entities.where(code: billing_entity_codes)
          return not_found_error(resource: "billing_entity") if billing_entities.count != billing_entity_codes.uniq.count
        end

        result = CustomersQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          search_term:,
          filters: filter_params.merge(billing_entity_ids: billing_entities&.ids)
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.customers.includes(:taxes, :integration_customers),
              ::V1::CustomerSerializer,
              collection_name: "customers",
              meta: pagination_metadata(result.customers),
              includes: %i[taxes integration_customers]
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        customer = current_organization.customers.find_by(external_id: params[:external_id])

        return not_found_error(resource: "customer") unless customer

        render_customer(customer)
      end

      def destroy
        customer = current_organization.customers.find_by(external_id: params[:external_id])
        result = ::Customers::DestroyService.call(customer:)

        if result.success?
          render_customer(result.customer)
        else
          render_error_response(result)
        end
      end

      def checkout_url
        customer = current_organization.customers.find_by(external_id: params[:customer_external_id])

        result = ::Customers::GenerateCheckoutUrlService.call(customer:)

        if result.success?
          render(
            json: ::V1::PaymentProviders::CustomerCheckoutSerializer.new(
              customer,
              root_name: "customer",
              checkout_url: result.checkout_url
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def create_params
        params.expect(customer: [
          :account_type,
          :external_id,
          :name,
          :firstname,
          :lastname,
          :customer_type,
          :country,
          :address_line1,
          :address_line2,
          :state,
          :zipcode,
          :email,
          :city,
          :url,
          :phone,
          :logo_url,
          :legal_name,
          :legal_number,
          :tax_identification_number,
          :currency,
          :timezone,
          :net_payment_term,
          :external_salesforce_id,
          :finalize_zero_amount_invoice,
          :skip_invoice_custom_sections,
          :billing_entity_code,
          integration_customers: [
            [
              :id,
              :external_customer_id,
              :integration_type,
              :integration_code,
              :subsidiary_id,
              :sync_with_provider,
              :targeted_object
            ]
          ],
          billing_configuration: [
            :invoice_grace_period,
            :subscription_invoice_issuing_date_anchor,
            :subscription_invoice_issuing_date_adjustment,
            :payment_provider,
            :payment_provider_code,
            :provider_customer_id,
            :sync,
            :sync_with_provider,
            :document_locale,
            provider_payment_methods: []
          ],
          metadata: [
            [
              :id,
              :key,
              :value,
              :display_in_invoice
            ]
          ],
          shipping_address: [
            :address_line1,
            :address_line2,
            :city,
            :zipcode,
            :state,
            :country
          ],
          tax_codes: [],
          invoice_custom_section_codes: []
        ])
      end

      def render_customer(customer)
        render(
          json: ::V1::CustomerSerializer.new(
            customer,
            root_name: "customer",
            includes: %i[taxes integration_customers applicable_invoice_custom_sections error_details]
          )
        )
      end

      def resource_name
        "customer"
      end
    end
  end
end
