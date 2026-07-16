# frozen_string_literal: true

module Analytics
  class Base < ApplicationRecord
    self.abstract_class = true

    def self.find_all_by(organization_id, **args)
      if args[:expire_cache] == true && args[:external_customer_id].present?
        expire_cache_for_customer(organization_id, args[:external_customer_id])
      end

      Rails.cache.fetch(cache_key(organization_id, **args), expires_in: cache_expiration) do
        sql = query(organization_id, **args)

        result = ActiveRecord::Base.connection.exec_query(sql)
        result.to_a
      end
    end

    def self.cache_expiration
      4.hours
    end

    def self.expire_cache_for_customer(organization_id, external_customer_id)
      raise NotImplementedError
    end
  end
end
