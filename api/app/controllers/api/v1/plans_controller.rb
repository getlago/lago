# frozen_string_literal: true

module Api
  module V1
    class PlansController < Api::BaseController
      def create
        result = ::Plans::CreateService.call(
          input_params.merge(organization_id: current_organization.id).to_h.deep_symbolize_keys
        )

        if result.success?
          render_plan(result.plan)
        else
          render_error_response(result)
        end
      end

      def update
        plan = current_organization.plans.parents.find_by(code: params[:code])
        result = ::Plans::UpdateService.call(plan:, params: input_params.to_h.deep_symbolize_keys)

        if result.success?
          # Reload to eager-load relationships, like :entitlements
          plan = Plan.includes(
            :usage_thresholds,
            :fixed_charges,
            entitlements: [:feature, values: :privilege]
          ).find(result.plan.id)

          render_plan(plan)
        else
          render_error_response(result)
        end
      end

      def destroy
        plan = current_organization.plans.parents.find_by(code: params[:code])
        result = ::Plans::PrepareDestroyService.call(plan:)

        if result.success?
          # Reload to eager-load relationships, like :entitlements
          plan = Plan.with_discarded.includes(
            :usage_thresholds,
            entitlements: [:feature, values: :privilege]
          ).find(result.plan.id)

          render_plan(plan)
        else
          render_error_response(result)
        end
      end

      def show
        plan = current_organization.plans.parents
          .includes(
            :usage_thresholds,
            entitlements: [:feature, values: :privilege]
          )
          .find_by(code: params[:code])

        if plan
          render_plan(plan)
        else
          not_found_error(resource: "plan")
        end
      end

      def index
        result = PlansQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: {include_pending_deletion: true}
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.plans.includes(
                :usage_thresholds,
                :taxes,
                :minimum_commitment,
                entitlements: [:feature, values: :privilege]
              ),
              ::V1::PlanSerializer,
              collection_name: "plans",
              meta: pagination_metadata(result.plans),
              includes: %i[charges usage_thresholds applicable_usage_thresholds taxes minimum_commitment entitlements]
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def input_params
        params.require(:plan).permit(
          :name,
          :invoice_display_name,
          :code,
          :interval,
          :description,
          :amount_cents,
          :amount_currency,
          :trial_period,
          :pay_in_advance,
          :bill_charges_monthly,
          :bill_fixed_charges_monthly,
          :cascade_updates,
          metadata: {},
          tax_codes: [],
          minimum_commitment: [
            :id,
            :invoice_display_name,
            :amount_cents,
            {tax_codes: []}
          ],
          charges: [
            :id,
            :code,
            :invoice_display_name,
            :billable_metric_id,
            :charge_model,
            :pay_in_advance,
            :prorated,
            :invoiceable,
            :regroup_paid_fees,
            :min_amount_cents,
            :accepts_target_wallet,
            {
              properties: {}
            },
            {
              filters: [
                :invoice_display_name,
                {
                  properties: {},
                  values: {}
                }
              ]
            },
            {tax_codes: []},
            {
              applied_pricing_unit: [
                :code,
                :conversion_rate
              ]
            }
          ],
          fixed_charges: [
            :id,
            :code,
            :invoice_display_name,
            :units,
            :add_on_id,
            :apply_units_immediately,
            :charge_model,
            :pay_in_advance,
            :prorated,
            {properties: {}},
            {tax_codes: []}
          ],
          usage_thresholds: [
            :id,
            :threshold_display_name,
            :amount_cents,
            :recurring
          ]
        )
      end

      def render_plan(plan)
        render(
          json: ::V1::PlanSerializer.new(
            plan,
            root_name: "plan",
            includes: %i[charges fixed_charges usage_thresholds applicable_usage_thresholds taxes minimum_commitment entitlements]
          )
        )
      end

      def resource_name
        "plan"
      end
    end
  end
end
