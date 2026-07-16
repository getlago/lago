# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Payloads
        class Hubspot < Integrations::Aggregator::Subscriptions::Payloads::BasePayload
          def create_body
            {
              "objectType" => integration.subscriptions_object_type_id,
              "input" => {
                "associations" => [],
                "properties" => {
                  "lago_subscription_id" => subscription.id,
                  "lago_external_subscription_id" => subscription.external_id,
                  "lago_billing_time" => subscription.billing_time,
                  "lago_subscription_name" => subscription.name,
                  "lago_subscription_plan_code" => subscription.plan.code,
                  "lago_subscription_status" => subscription.status,
                  "lago_subscription_created_at" => formatted_date(subscription.created_at),
                  "lago_subscription_started_at" => formatted_date(subscription.started_at),
                  "lago_subscription_ending_at" => formatted_date(subscription.ending_at),
                  "lago_subscription_at" => formatted_date(subscription.subscription_at),
                  "lago_subscription_terminated_at" => formatted_date(subscription.terminated_at),
                  "lago_subscription_trial_ended_at" => formatted_date(subscription.trial_ended_at),
                  "lago_subscription_link" => subscription_url
                }
              }
            }
          end

          def update_body
            {
              "objectId" => integration_subscription.external_id,
              "objectType" => integration.subscriptions_object_type_id,
              "input" => {
                "properties" => {
                  "lago_subscription_id" => subscription.id,
                  "lago_external_subscription_id" => subscription.external_id,
                  "lago_billing_time" => subscription.billing_time,
                  "lago_subscription_name" => subscription.name,
                  "lago_subscription_plan_code" => subscription.plan.code,
                  "lago_subscription_status" => subscription.status,
                  "lago_subscription_created_at" => formatted_date(subscription.created_at),
                  "lago_subscription_started_at" => formatted_date(subscription.started_at),
                  "lago_subscription_ending_at" => formatted_date(subscription.ending_at),
                  "lago_subscription_at" => formatted_date(subscription.subscription_at),
                  "lago_subscription_terminated_at" => formatted_date(subscription.terminated_at),
                  "lago_subscription_trial_ended_at" => formatted_date(subscription.trial_ended_at),
                  "lago_subscription_link" => subscription_url
                }
              }
            }
          end

          def customer_association_body
            {
              "objectType" => integration.subscriptions_object_type_id,
              "objectId" => integration_subscription.external_id,
              "toObjectType" => integration_customer.object_type,
              "toObjectId" => integration_customer.external_customer_id,
              "input" => []
            }
          end
        end
      end
    end
  end
end
