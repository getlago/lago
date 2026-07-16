# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      module Charges
        class FiltersController < Api::V1::Subscriptions::BaseController
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
            result = ::Subscriptions::ChargeFilters::CreateService.call(
              subscription:,
              charge:,
              params: input_params.to_h.deep_symbolize_keys
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
            result = ::Subscriptions::ChargeFilters::UpdateOrOverrideService.call(
              subscription:,
              charge:,
              charge_filter:,
              params: input_params.to_h.deep_symbolize_keys
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
            result = ::Subscriptions::ChargeFilters::DestroyService.call(
              subscription:,
              charge:,
              charge_filter:
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

          private

          attr_reader :charge, :charge_filter

          def resource_name
            "subscription"
          end

          def input_params
            params.require(:filter).permit(
              :invoice_display_name,
              properties: {},
              values: {}
            )
          end

          def find_charge
            @charge = subscription.plan.charges.find_by(code: params[:charge_code])
            not_found_error(resource: "charge") unless @charge
          end

          def find_charge_filter
            @charge_filter = charge.filters.find_by(id: params[:id])
            not_found_error(resource: "charge_filter") unless @charge_filter
          end
        end
      end
    end
  end
end
