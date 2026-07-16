# frozen_string_literal: true

module Api
  module V1
    module Plans
      class FixedChargesController < BaseController
        before_action :find_fixed_charge, only: %i[show update destroy]

        def index
          fixed_charges = plan.fixed_charges
            .parents
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
              includes: %i[taxes]
            )
          )
        end

        def show
          render(
            json: ::V1::FixedChargeSerializer.new(
              fixed_charge,
              root_name: "fixed_charge",
              includes: %i[taxes]
            )
          )
        end

        def create
          result = FixedCharges::CreateService.call(
            plan:, params: input_params.to_h.deep_symbolize_keys, cascade_updates: cascade_updates?
          )

          if result.success?
            render(
              json: ::V1::FixedChargeSerializer.new(
                result.fixed_charge,
                root_name: "fixed_charge",
                includes: %i[taxes]
              )
            )
          else
            render_error_response(result)
          end
        end

        def update
          result = FixedCharges::UpdateService.call(
            fixed_charge:,
            params: input_params.to_h.deep_symbolize_keys,
            timestamp: Time.current.to_i,
            cascade_updates: cascade_updates?
          )

          if result.success?
            render(
              json: ::V1::FixedChargeSerializer.new(
                result.fixed_charge,
                root_name: "fixed_charge",
                includes: %i[taxes]
              )
            )
          else
            render_error_response(result)
          end
        end

        def destroy
          result = FixedCharges::DestroyService.call(fixed_charge:, cascade_updates: cascade_updates?)

          if result.success?
            render(
              json: ::V1::FixedChargeSerializer.new(
                result.fixed_charge,
                root_name: "fixed_charge",
                includes: %i[taxes]
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        attr_reader :fixed_charge

        def input_params
          params.require(:fixed_charge).permit(
            :add_on_id,
            :add_on_code,
            :code,
            :invoice_display_name,
            :charge_model,
            :pay_in_advance,
            :prorated,
            :units,
            :apply_units_immediately,
            properties: {},
            tax_codes: []
          )
        end

        def cascade_updates?
          ActiveModel::Type::Boolean.new.cast(params.dig(:fixed_charge, :cascade_updates))
        end

        def find_fixed_charge
          @fixed_charge = plan.fixed_charges.parents.find_by!(code: params[:code])
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "fixed_charge")
        end
      end
    end
  end
end
