# frozen_string_literal: true

module Api
  module V1
    module Plans
      class ChargesController < BaseController
        before_action :find_charge, only: %i[show update destroy]

        def index
          charges = plan.charges
            .parents
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

        def create
          result = ::Charges::CreateService.call(
            plan:, params: input_params.to_h.deep_symbolize_keys, cascade_updates: cascade_updates?
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

        def update
          result = ::Charges::UpdateService.call(
            charge:,
            params: input_params.to_h.deep_symbolize_keys,
            cascade_updates: cascade_updates?
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

        def destroy
          result = ::Charges::DestroyService.call(charge:, cascade_updates: cascade_updates?)

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

        def input_params
          params.require(:charge).permit(
            :billable_metric_id,
            :code,
            :invoice_display_name,
            :charge_model,
            :pay_in_advance,
            :prorated,
            :invoiceable,
            :regroup_paid_fees,
            :min_amount_cents,
            :accepts_target_wallet,
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

        def cascade_updates?
          ActiveModel::Type::Boolean.new.cast(params.dig(:charge, :cascade_updates))
        end

        def find_charge
          @charge = plan.charges.parents.find_by!(code: params[:code])
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "charge")
        end
      end
    end
  end
end
