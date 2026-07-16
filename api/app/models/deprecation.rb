# frozen_string_literal: true

require "csv"

class Deprecation
  EXPIRE_IN = 1.month

  class << self
    def report(feature_name, organization_id)
      Rails.cache.write(cache_key(feature_name, organization_id, "last_seen_at"), Time.current, expires_in: EXPIRE_IN)
      Rails.cache.increment(cache_key(feature_name, organization_id, "count"), 1, expires_in: EXPIRE_IN)
    end

    def get_all(feature_name)
      Organization.pluck(:id).filter_map do |organization_id|
        h = get(feature_name, organization_id)
        h[:last_seen_at] ? h : nil
      end
    end

    def get_all_as_csv(feature_name)
      lines = get_all(feature_name)
      orgs = Organization.find(lines.pluck(:organization_id)).index_by(&:id)

      CSV.generate do |csv|
        csv << %w[org_id org_name org_email last_event_sent_at count]

        lines.each do |d|
          o = orgs[d[:organization_id]]
          csv << [d[:organization_id], o.name, o.email, d[:last_seen_at], d[:count]]
        end
      end
    end

    def get(feature_name, organization_id)
      last_seen_at = Rails.cache.read(cache_key(feature_name, organization_id, "last_seen_at"))
      count = Rails.cache.read(cache_key(feature_name, organization_id, "count"), raw: true).to_i

      {organization_id:, last_seen_at:, count:}
    end

    def reset_all(feature_name)
      Organization.pluck(:id).each do |organization_id|
        reset(feature_name, organization_id)
      end
    end

    def reset(feature_name, organization_id)
      Rails.cache.delete(cache_key(feature_name, organization_id, "count"))
      Rails.cache.delete(cache_key(feature_name, organization_id, "last_seen_at"))
    end

    private

    def cache_key(feature_name, organization_id, suffix)
      "deprecation:#{feature_name}:#{organization_id}:#{suffix}"
    end
  end
end
