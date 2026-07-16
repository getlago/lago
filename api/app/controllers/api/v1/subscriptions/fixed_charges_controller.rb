# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      class FixedChargesController < BaseController
        before_action :find_fixed_charge, only: %i[show update]

        def index
          fixed_charges = subscription.plan.fixed_charges
            .includes(:add_on, :taxes)
            .order(created_at: :desc)
            .page(params[:page])
            .per(params[:per_page] || PER_PAGE)

          render(
            json: ::CollectionSerializer.new(
              fixed_charges,
              ::V1::FixedChargeSerializer,
              collection_name: "fixed_charges",
              meta: pagination_metadata(fixed_charges),
              includes: %i[taxes],
              effective_units_by_id: effective_units_map_for(fixed_charges)
            )
          )
        end

        def show
          render(
            json: ::V1::FixedChargeSerializer.new(
              fixed_charge,
              root_name: "fixed_charge",
              includes: %i[taxes],
              effective_units_by_id: effective_units_map_for([fixed_charge])
            )
          )
        end

        def update
          result = ::Subscriptions::UpdateOrOverrideFixedChargeService.call(
            subscription:,
            fixed_charge:,
            params: input_params.to_h.deep_symbolize_keys
          )

          if result.success?
            render(
              json: ::V1::FixedChargeSerializer.new(
                result.fixed_charge,
                root_name: "fixed_charge",
                includes: %i[taxes],
                effective_units_by_id: effective_units_map_for([result.fixed_charge])
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        attr_reader :fixed_charge

        def effective_units_map_for(fixed_charges)
          ::Subscription::FixedChargeUnitsOverride.units_map_for(subscription:, fixed_charges:)
        end

        def resource_name
          "subscription"
        end

        def input_params
          params.require(:fixed_charge).permit(
            :invoice_display_name,
            :units,
            :apply_units_immediately,
            properties: {},
            tax_codes: []
          )
        end

        def find_fixed_charge
          @fixed_charge = subscription.plan.fixed_charges.find_by(code: params[:code])
          not_found_error(resource: "fixed_charge") unless @fixed_charge
        end
      end
    end
  end
end
