# frozen_string_literal: true

class BaseQuery < BaseService
  # nil values force Kaminari to apply its default values for page and limit.
  DEFAULT_PAGINATION_PARAMS = {page: nil, limit: nil}
  DEFAULT_ORDER = {created_at: :desc}
  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  Pagination = Struct.new(:page, :limit, keyword_init: true)
  Filters = BaseFilters

  def initialize(organization:, pagination: DEFAULT_PAGINATION_PARAMS, filters: {}, search_term: nil, order: nil)
    @organization = organization
    @pagination_params = pagination
    @filters = self.class::Filters.new(**(filters || {}))
    @search_term = search_term.to_s.strip
    @order = order

    super
  end

  private

  attr_reader :organization, :pagination_params, :filters, :search_term, :order

  def validate_filters
    validation_result = filters_contract.call(filters.to_h)

    unless validation_result.success?
      errors = validation_result.errors.to_h
      result.validation_failure!(errors:)
    end

    result
  end

  def pagination
    return if pagination_params.blank?

    @pagination ||= Pagination.new(
      page: pagination_params[:page],
      limit: pagination_params[:limit]
    )
  end

  def paginate(scope)
    return scope unless pagination

    scope.page(pagination.page).per(pagination.limit)
  end

  def parse_datetime_filter(field_name)
    value = filters[field_name]
    return value if Utils::Datetime.datetime_like?(value)

    parsed_value = Utils::Datetime.parse_iso8601(value)
    return parsed_value if parsed_value

    result.single_validation_failure!(field: field_name.to_sym, error_code: "invalid_date")
      .raise_if_error!
  end

  # Apply consistent ordering across query objects
  def apply_consistent_ordering(scope, default_order: DEFAULT_ORDER)
    scope.order(default_order).order(id: :asc)
  end
end
