# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      class AlertsController < BaseController
        before_action :find_alert, only: %i[show update destroy]

        def destroy_all
          result = UsageMonitoring::Alerts::DestroyAllService.call(
            alertable: subscription
          )

          if result.success?
            head(:ok)
          else
            render_error_response(result)
          end
        end

        def index
          result = UsageMonitoring::AlertsQuery.call(
            organization: current_organization,
            filters: {
              subscription_external_id: subscription.external_id
            },
            pagination: {
              page: params[:page],
              limit: params[:per_page] || PER_PAGE
            }
          )

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                result.alerts.includes(:thresholds, :billable_metric),
                ::V1::UsageMonitoring::AlertSerializer,
                collection_name: "alerts",
                meta: pagination_metadata(result.alerts),
                includes: %i[thresholds]
              )
            )
          else
            render_error_response(result)
          end
        end

        def show
          render_alert(alert)
        end

        def create
          if params[:alerts].present?
            create_batch
          else
            create_single
          end
        end

        def update
          result = UsageMonitoring::UpdateAlertService.call(
            alert:,
            params: update_params.to_h
          )

          if result.success?
            render_alert(result.alert)
          else
            render_error_response(result)
          end
        end

        def destroy
          result = UsageMonitoring::DestroyAlertService.call(alert:)

          if result.success?
            render_alert(result.alert)
          else
            render_error_response(result)
          end
        end

        private

        def create_single
          result = UsageMonitoring::CreateAlertService.call(
            organization: current_organization,
            alertable: subscription,
            params: create_params.to_h
          )

          if result.success?
            render_alert(result.alert)
          else
            render_error_response(result)
          end
        end

        def create_batch
          result = UsageMonitoring::Alerts::CreateBatchService.call(
            organization: current_organization,
            alertable: subscription,
            alerts_params: batch_create_params[:alerts]
          )

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                result.alerts,
                ::V1::UsageMonitoring::AlertSerializer,
                collection_name: "alerts",
                includes: %i[thresholds]
              )
            )
          else
            render_error_response(result)
          end
        end

        attr_reader :subscription, :alert

        def find_alert
          @alert = current_organization.alerts.find_by!(
            subscription_external_id: subscription.external_id,
            code: params[:code]
          )
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "alert")
        end

        def render_alert(alert)
          render(
            json: ::V1::UsageMonitoring::AlertSerializer.new(
              alert,
              root_name: "alert",
              includes: %i[thresholds]
            )
          )
        end

        def create_params
          params.require(:alert).permit(:alert_type, :code, :name, :billable_metric_code, thresholds: %i[code value recurring])
        end

        def update_params
          params.require(:alert).permit(:code, :name, :billable_metric_code, thresholds: %i[code value recurring])
        end

        def batch_create_params
          params.permit(alerts: [:alert_type, :code, :name, :billable_metric_code, {thresholds: %i[code value recurring]}])
        end

        def resource_name
          "alert"
        end
      end
    end
  end
end
