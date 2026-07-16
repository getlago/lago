# frozen_string_literal: true

module Pagination
  extend ActiveSupport::Concern

  # Default number of records per page
  PER_PAGE = 100
  # The TTL for caching the number of records
  DEFAULT_TTL = 30.minutes.freeze

  def pagination_metadata(records, **count_params)
    current_page = prev_page = next_page = total_pages = nil
    total_count = _count_total(**count_params) { records.total_count }

    if total_count.positive?
      current_page = records.current_page
      total_pages = _total_pages(records, total_count)
      next_page = current_page + 1 if current_page < total_pages
      prev_page = current_page - 1 if current_page > 1
    end

    {
      "current_page" => current_page.to_i,
      "next_page" => next_page,
      "prev_page" => prev_page,
      "total_pages" => total_pages.to_i,
      "total_count" => total_count
    }
  end

  private

  # Computes total pages from the record count.
  # For kaminari collections, derives it from limit_value to avoid an extra COUNT(*) query.
  # For custom result objects (e.g. PastUsageQuery::Result), uses the precomputed value.
  def _total_pages(records, total_count)
    return records.total_pages unless records.respond_to?(:limit_value)

    (total_count.to_f / records.limit_value).ceil
  end

  def _count_total(key: nil, organization_id: nil, params: nil, ttl: DEFAULT_TTL)
    # backward-compatibility: skip caching if it is not requested explicitly
    return yield unless key && organization_id && params

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || PER_PAGE).to_i

    # prepare the key for caching
    hash_data = _deep_sort(params.except(:page).merge(organization_id:))
    hash = Digest::SHA256.hexdigest(hash_data.to_json)
    cache_key = "pagination_count/#{key}/#{hash}"

    # Re-calculate on the last page because the number of records could have changed.
    # If the count is small (less than the page size), caching is useless but re-querying is acceptable.
    cached = Rails.cache.read(cache_key)
    return cached if cached.to_i > per_page * page

    yield.tap { |count| Rails.cache.write(cache_key, count, expires_in: ttl) }
  end

  # Recursively converts hashes into sorted arrays of pairs
  # to ensure deterministic JSON serialization regardless of key order.
  def _deep_sort(obj)
    case obj
    when Hash, ActionController::Parameters
      obj.to_h.map { |k, v| [k.to_s, _deep_sort(v)] }.sort_by(&:first)
    when Array then obj.map { |v| _deep_sort(v) }
    else obj
    end
  end
end
