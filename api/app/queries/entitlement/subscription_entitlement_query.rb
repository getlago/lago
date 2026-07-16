# frozen_string_literal: true

module Entitlement
  class SubscriptionEntitlementQuery < BaseQuery
    Result = BaseResult[:entitlements]
    Filters = BaseFilters[:subscription_id, :plan_id]

    def call
      features_result = ActiveRecord::Base.connection.exec_query(
        feature_sql,
        "subscription_entitlement_features",
        [filters.plan_id, filters.subscription_id]
      )

      features = features_result.map do |row|
        SubscriptionEntitlement.new(row)
      end

      plan_entitlement_ids = features.map(&:plan_entitlement_id).compact.uniq
      sub_entitlement_ids = features.map(&:sub_entitlement_id).compact.uniq

      privileges_result = ActiveRecord::Base.connection.exec_query(
        privilege_sql,
        "subscription_entitlement_privileges",
        [prepare_ids(plan_entitlement_ids), prepare_ids(sub_entitlement_ids), filters.subscription_id]
      )

      privileges_by_feature_id = privileges_result.map do |row|
        SubscriptionEntitlementPrivilege.new(row)
      end.group_by(&:entitlement_feature_id)

      features.each do |f|
        f.privileges = privileges_by_feature_id[f.entitlement_feature_id] || []
      end

      features
    end

    private

    def feature_sql
      <<~SQL
        WITH
            plan_entitlements AS (
                SELECT
                    *
                FROM
                    entitlement_entitlements
                WHERE
                    plan_id = $1
                    AND deleted_at IS NULL
            ),
            sub_entitlements AS (
                SELECT
                    *
                FROM
                    entitlement_entitlements
                WHERE
                    subscription_id = $2
                    AND deleted_at IS NULL
            )
        SELECT
            COALESCE(pe.organization_id, se.organization_id) AS organization_id,
            COALESCE(pe.entitlement_feature_id, se.entitlement_feature_id) AS entitlement_feature_id,
            f.code,
            f.name,
            f.description,
            pe.id AS plan_entitlement_id,
            se.id AS sub_entitlement_id,
            pe.plan_id AS plan_id,
            se.subscription_id AS subscription_id,
            COALESCE(pe.created_at, se.created_at) AS ordering_date
        FROM
            plan_entitlements pe
            FULL OUTER JOIN sub_entitlements se ON pe.entitlement_feature_id = se.entitlement_feature_id
            JOIN entitlement_features f ON f.id = COALESCE(pe.entitlement_feature_id, se.entitlement_feature_id)
        WHERE
            f.deleted_at IS NULL
            AND (
                pe.entitlement_feature_id IS NULL           -- Feature is in sub but not in plan
                OR pe.entitlement_feature_id NOT IN (       -- Feature is in plan but removed from sub
                    SELECT
                        entitlement_feature_id
                    FROM
                        entitlement_subscription_feature_removals
                    WHERE
                        subscription_id = $2
                        AND entitlement_feature_id IS NOT NULL
                        AND deleted_at IS NULL
                )
            )
        ORDER BY
            ordering_date
      SQL
    end

    def privilege_sql
      # TODO: ADD EXCLUSION FOR REMOVED PRIVILEGES
      # via subquery, same as feature_sql

      <<~SQL
        WITH
            plan_values AS (
                SELECT
                    *
                FROM
                    entitlement_entitlement_values
                WHERE
                    deleted_at IS NULL
                    AND entitlement_entitlement_id = ANY ($1::UUID [])
            ),
            sub_values AS (
                SELECT
                    *
                FROM
                    entitlement_entitlement_values
                WHERE
                    deleted_at IS NULL
                    AND entitlement_entitlement_id = ANY ($2::UUID [])
            )
        SELECT
            COALESCE(pv.organization_id, sv.organization_id) AS organization_id,
            p.entitlement_feature_id,
            p.code,
            COALESCE(sv.value, pv.value) AS value,
            pv.value AS plan_value,
            sv.value AS subscription_value,
            p.name,
            p.value_type,
            p.config,
            COALESCE(pv.created_at, sv.created_at) AS ordering_date,
            pv.entitlement_entitlement_id AS plan_entitlement_id,
            sv.entitlement_entitlement_id AS sub_entitlement_id,
            pv.id AS plan_entitlement_value_id,
            sv.id AS sub_entitlement_value_id
        FROM
            plan_values pv
            FULL OUTER JOIN sub_values sv ON pv.entitlement_privilege_id = sv.entitlement_privilege_id
            JOIN entitlement_privileges p ON p.id = COALESCE(pv.entitlement_privilege_id, sv.entitlement_privilege_id)
        WHERE
            p.deleted_at IS NULL
            AND (
                pv.entitlement_privilege_id IS NULL           -- Privilege is in sub but not in plan
                OR pv.entitlement_privilege_id NOT IN (       -- Privilege is in plan but removed from sub
                    SELECT
                        entitlement_privilege_id
                    FROM
                        entitlement_subscription_feature_removals
                    WHERE
                        subscription_id = $3
                        AND entitlement_privilege_id IS NOT NULL
                        AND deleted_at IS NULL
                )
            )
        ORDER BY
            ordering_date
      SQL
    end

    def prepare_ids(ids)
      "{#{ids.map { ActiveRecord::Base.connection.quote_string(it) }.join(",")}}"
    end
  end
end
