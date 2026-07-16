# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      class ChargesController < BaseController
        before_action :find_charge, only: %i[show update]

        def index
          charges = subscription.plan.charges
            .includes(:billable_metric, :taxes, :applied_pricing_unit, :pricing_unit, filters: :billable_metric_filters)
            .order(created_at: :desc)
            .page(params[:page])
            .per(params[:per_page] || PER_PAGE)

          render(
            json: ::CollectionSerializer.new(
              charges,
              ::V1::ChargeSerializer,
              collection_name: "charges",
              meta: pagination_metadata(charges),
              includes: %i[taxes]
            )
          )
        end

        def show
          render(
            json: ::V1::ChargeSerializer.new(
              charge,
              root_name: "charge",
              includes: %i[taxes]
            )
          )
        end

        def update
          result = ::Subscriptions::UpdateOrOverrideChargeService.call(
            subscription:,
            charge:,
            params: input_params.to_h.deep_symbolize_keys
          )

          if result.success?
            render(
              json: ::V1::ChargeSerializer.new(
                result.charge,
                root_name: "charge",
                includes: %i[taxes]
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        attr_reader :charge

        def resource_name
          "subscription"
        end

        def input_params
          params.require(:charge).permit(
            :invoice_display_name,
            :min_amount_cents,
            properties: {},
            filters: [
              :invoice_display_name,
              {
                properties: {},
                values: {}
              }
            ],
            tax_codes: [],
            applied_pricing_unit: %i[code conversion_rate]
          )
        end

        def find_charge
          @charge = subscription.plan.charges.find_by(code: params[:code])
          not_found_error(resource: "charge") unless @charge
        end
      end
    end
  end
end
