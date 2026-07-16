select
    billable_metrics.organization_id,
    billable_metrics.code,
    billable_metrics.aggregation_type,
    billable_metrics.field_name,
    charges.plan_id,
    charges.id as charge_id,
    charges.pay_in_advance,
    (
        case when charges.charge_model = 0 -- Standard
        then
            charges.properties->'grouped_by'
        else
            null
        end
    ) as grouped_by,
    charge_filters.id as charge_filter_id,
    json_object_agg(
        billable_metric_filters.key,
        coalesce(charge_filter_values.values, '{}')
        order by billable_metric_filters.key asc
    ) FILTER (WHERE billable_metric_filters.key IS NOT NULL) AS filters,
    (
        case when charges.charge_model = 0 -- Standard
        then
            charge_filters.properties->'grouped_by'
        else
            null
        end
    ) AS filters_grouped_by

from billable_metrics
    inner join charges on charges.billable_metric_id = billable_metrics.id
    left join charge_filters on charge_filters.charge_id = charges.id
    left join charge_filter_values on charge_filter_values.charge_filter_id = charge_filters.id
    left join billable_metric_filters on charge_filter_values.billable_metric_filter_id = billable_metric_filters.id
where
    billable_metrics.deleted_at is null
    and charges.deleted_at is null
    and charge_filters.deleted_at is null
    and charge_filter_values.deleted_at is null
    and billable_metric_filters.deleted_at is null
group by
    billable_metrics.organization_id,
    billable_metrics.code,
    billable_metrics.aggregation_type,
    billable_metrics.field_name,
    charges.plan_id,
    charges.id,
    charge_filters.id
