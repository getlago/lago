# frozen_string_literal: true

module Api
  module V1
    module Plans
      module Charges
        class FiltersController < Plans::BaseController
          before_action :find_charge
          before_action :find_charge_filter, only: %i[show update destroy]

          def index
            charge_filters = charge.filters
              .includes(:charge, :billable_metric_filters)
              .page(params[:page])
              .per(params[:per_page] || PER_PAGE)

            render(
              json: ::CollectionSerializer.new(
                charge_filters,
                ::V1::ChargeFilterSerializer,
                collection_name: "filters",
                meta: pagination_metadata(charge_filters)
              )
            )
          end

          def show
            render(json: ::V1::ChargeFilterSerializer.new(charge_filter, root_name: "filter"))
          end

          def create
            result = ChargeFilters::CreateService.call(
              charge:, params: input_params.to_h.deep_symbolize_keys, cascade_updates: cascade_updates?
            )

            if result.success?
              render(
                json: ::V1::ChargeFilterSerializer.new(
                  result.charge_filter,
                  root_name: "filter"
                )
              )
            else
              render_error_response(result)
            end
          end

          def update
            result = ChargeFilters::UpdateService.call(
              charge_filter:,
              params: input_params.to_h.deep_symbolize_keys,
              cascade_updates: cascade_updates?
            )

            if result.success?
              render(
                json: ::V1::ChargeFilterSerializer.new(
                  result.charge_filter,
                  root_name: "filter"
                )
              )
            else
              render_error_response(result)
            end
          end

          def destroy
            result = ChargeFilters::DestroyService.call(charge_filter:, cascade_updates: cascade_updates?)

            if result.success?
              render(
                json: ::V1::ChargeFilterSerializer.new(
                  result.charge_filter,
                  root_name: "filter"
                )
              )
            else
              render_error_response(result)
            end
          end

          private

          attr_reader :charge, :charge_filter

          def input_params
            params.require(:filter).permit(
              :invoice_display_name,
              properties: {},
              values: {}
            )
          end

          def cascade_updates?
            ActiveModel::Type::Boolean.new.cast(params.dig(:filter, :cascade_updates))
          end

          def find_charge
            @charge = plan.charges.parents.find_by!(code: params[:charge_code])
          rescue ActiveRecord::RecordNotFound
            not_found_error(resource: "charge")
          end

          def find_charge_filter
            @charge_filter = charge.filters.find_by!(id: params[:id])
          rescue ActiveRecord::RecordNotFound
            not_found_error(resource: "charge_filter")
          end
        end
      end
    end
  end
end
