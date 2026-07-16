# frozen_string_literal: true

class CacheService < BaseService
  def initialize(*, expires_in: nil)
    @expires_in = expires_in
    super(nil)
  end

  def self.expire_cache(*, **)
    new(*, **).expire_cache
  end

  def cache_key
    raise NotImplementedError
  end

  def call(&)
    # NOTE: We don't rely on fetch here because some services compute expires_in = 0
    #       and we think this is the root of an invalid expiration time passed to Redis
    value = Rails.cache.read(cache_key)
    return value if value

    value = yield

    # NOTE: It seems that passing expires_in: 0 is not a NO-OP, so bypass manually
    if expires_in.nil? || expires_in > 0
      Rails.cache.write(cache_key, value, expires_in:)
    end

    value
  end

  def expire_cache
    Rails.cache.delete(cache_key)
  end

  private

  attr_reader :expires_in
end
