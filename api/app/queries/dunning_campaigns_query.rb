# frozen_string_literal: true

class DunningCampaignsQuery < BaseQuery
  Result = BaseResult[:dunning_campaigns]
  Filters = BaseFilters[:currency, :applied_to_organization]

  DEFAULT_ORDER = "name"

  def call
    dunning_campaigns = base_scope.result
    dunning_campaigns = paginate(dunning_campaigns)
    dunning_campaigns = dunning_campaigns.order(order)
    dunning_campaigns = apply_consistent_ordering(dunning_campaigns)

    dunning_campaigns = with_applied_to_organization(dunning_campaigns) unless filters.applied_to_organization.nil?
    dunning_campaigns = with_currency_threshold(dunning_campaigns) if filters.currency.present?

    result.dunning_campaigns = dunning_campaigns
    result
  end

  private

  def base_scope
    DunningCampaign.where(organization:).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      name_cont: search_term,
      code_cont: search_term
    }
  end

  def order
    DunningCampaign::ORDERS.include?(@order) ? @order : DEFAULT_ORDER
  end

  # TODO: remove this method when we not apply dunning campaign on organization anymore
  # will we need a way to filter by billing_entity_id?
  def with_applied_to_organization(scope)
    if filters.applied_to_organization
      scope.joins(:billing_entities).where(billing_entities: {id: organization.default_billing_entity.id})
    else
      scope.left_joins(:billing_entities).where(
        "billing_entities.id IS NULL OR billing_entities.id != ?",
        organization.default_billing_entity.id
      )
    end
  end

  def with_currency_threshold(scope)
    scope.with_currency_threshold(filters.currency)
  end
end
