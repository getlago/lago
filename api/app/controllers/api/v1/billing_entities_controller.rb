# frozen_string_literal: true

module Api
  module V1
    class BillingEntitiesController < Api::BaseController
      def index
        render(
          json: ::CollectionSerializer.new(
            current_organization.billing_entities,
            ::V1::BillingEntitySerializer,
            collection_name: "billing_entities"
          )
        )
      end

      def show
        entity = BillingEntity.find_by(code: params[:code], organization: current_organization)

        return not_found_error(resource: "billing_entity") if entity.blank?

        render(
          json: ::V1::BillingEntitySerializer.new(
            entity,
            root_name: "billing_entity",
            includes: [:taxes, :selected_invoice_custom_sections]
          )
        )
      end

      def create
        result = BillingEntities::CreateService.new(
          organization: current_organization,
          params: create_params
        ).call

        if result.success?
          render(
            json: ::V1::BillingEntitySerializer.new(
              result.billing_entity,
              root_name: "billing_entity"
            )
          )
        else
          render_error_response(result)
        end
      end

      def update
        entity = BillingEntity.find_by(code: params[:code], organization: current_organization)
        return not_found_error(resource: "billing_entity") if entity.blank?

        result = BillingEntities::UpdateService.call(billing_entity: entity, params: update_params)

        if result.success?
          render(
            json: ::V1::BillingEntitySerializer.new(
              result.billing_entity,
              root_name: "billing_entity",
              includes: [:taxes, :selected_invoice_custom_sections]
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def create_params
        params.require(:billing_entity).permit(
          :code,
          :name,
          :einvoicing,
          :email,
          :legal_name,
          :legal_number,
          :tax_identification_number,
          :address_line1,
          :address_line2,
          :phone,
          :city,
          :state,
          :zipcode,
          :country,
          :default_currency,
          :timezone,
          :document_numbering,
          :document_number_prefix,
          :finalize_zero_amount_invoice,
          :net_payment_term,
          :eu_tax_management,
          :logo,
          email_settings: [],
          billing_configuration: [
            :invoice_footer,
            :invoice_grace_period,
            :subscription_invoice_issuing_date_anchor,
            :subscription_invoice_issuing_date_adjustment,
            :document_locale
          ]
        )
      end

      def update_params
        params.require(:billing_entity).permit(
          :name,
          :einvoicing,
          :email,
          :legal_name,
          :legal_number,
          :tax_identification_number,
          :address_line1,
          :address_line2,
          :phone,
          :city,
          :state,
          :zipcode,
          :country,
          :default_currency,
          :timezone,
          :document_numbering,
          :document_number_prefix,
          :finalize_zero_amount_invoice,
          :net_payment_term,
          :eu_tax_management,
          :logo,
          email_settings: [],
          billing_configuration: [
            :invoice_footer,
            :invoice_grace_period,
            :subscription_invoice_issuing_date_anchor,
            :subscription_invoice_issuing_date_adjustment,
            :document_locale
          ],
          tax_codes: [],
          invoice_custom_section_codes: []
        )
      end

      def resource_name
        "billing_entity"
      end
    end
  end
end
