# frozen_string_literal: true

module Entitlement
  class Feature
    class SubscriptionsCountQuery < BaseQuery
      Result = BaseResult[:features]
      Filters = BaseFilters[:feature_ids]

      def call
        result = ActiveRecord::Base.connection.exec_query(
          subscriptions_count_query
        )

        result.each_with_object({}) do |row, hash|
          hash[row["feature_id"]] = row["count"]
        end
      end

      private

      def subscriptions_count_query
        ActiveRecord::Base.sanitize_sql_array([
          subscriptions_count_sql,
          filters.feature_ids,
          organization.id
        ])
      end

      def subscriptions_count_sql
        <<~SQL
          WITH
            plan_features AS (
              SELECT
                plan_id,
                entitlement_feature_id
              FROM
                entitlement_entitlements
              WHERE
                plan_id IS NOT NULL
                AND entitlement_feature_id IN (?)
            ),
            plan_subscriptions AS (
              SELECT
                coalesce(plans.parent_id, plan_id) AS plan_id,
                count(*)
              FROM
                subscriptions
                INNER JOIN plans ON plans.id = subscriptions.plan_id
              WHERE
                plans.deleted_at IS NULL
                AND plans.organization_id = ?
                AND subscriptions.status IN (0, 1)
              GROUP BY
                coalesce(plans.parent_id, plan_id)
            )
          SELECT
            plan_features.entitlement_feature_id AS feature_id,
            SUM(plan_subscriptions.count) AS count
          FROM
            plan_features
            INNER JOIN plan_subscriptions ON plan_features.plan_id = plan_subscriptions.plan_id
          GROUP BY
            plan_features.entitlement_feature_id
        SQL
      end
    end
  end
end
