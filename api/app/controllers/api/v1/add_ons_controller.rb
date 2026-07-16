# frozen_string_literal: true

module Api
  module V1
    class AddOnsController < Api::BaseController
      def create
        result = AddOns::CreateService.call(
          input_params
            .merge(organization_id: current_organization.id)
            .to_h
            .symbolize_keys
        )

        if result.success?
          render_add_on(result.add_on)
        else
          render_error_response(result)
        end
      end

      def update
        add_on = current_organization.add_ons.find_by(code: params[:code])
        result = AddOns::UpdateService.call(add_on:, params: input_params)

        if result.success?
          render_add_on(result.add_on)
        else
          render_error_response(result)
        end
      end

      def destroy
        add_on = current_organization.add_ons.find_by(code: params[:code])
        result = AddOns::DestroyService.call(add_on:)

        if result.success?
          render_add_on(result.add_on)
        else
          render_error_response(result)
        end
      end

      def show
        add_on = current_organization.add_ons.find_by(
          code: params[:code]
        )

        return not_found_error(resource: "add_on") unless add_on

        render_add_on(add_on)
      end

      def index
        result = AddOnsQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          }
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.add_ons.includes(:taxes),
              ::V1::AddOnSerializer,
              collection_name: "add_ons",
              meta: pagination_metadata(result.add_ons),
              includes: %i[taxes]
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def input_params
        params.require(:add_on).permit(
          :name,
          :invoice_display_name,
          :code,
          :amount_cents,
          :amount_currency,
          :description,
          tax_codes: []
        )
      end

      def render_add_on(add_on)
        render(
          json: ::V1::AddOnSerializer.new(
            add_on,
            root_name: "add_on",
            includes: %i[taxes]
          )
        )
      end

      def resource_name
        "add_on"
      end
    end
  end
end
