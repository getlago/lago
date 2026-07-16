# frozen_string_literal: true

module Auth
  class TokenService < BaseService
    THREE_HOURS = 10800
    ALGORITHM = "HS256"
    LAGO_TOKEN_HEADER = "x-lago-token"

    def self.encode(user: nil, user_id: nil, **extra)
      return nil if (user_id || user&.id).blank?

      JWT.encode(payload(user:, user_id:, **extra), ENV["SECRET_KEY_BASE"], ALGORITHM)
    end

    def self.decode(token:)
      return nil if token.blank?

      JWT.decode(token, ENV["SECRET_KEY_BASE"], true, {algorithm: ALGORITHM}).reduce({}, :merge)
    end

    def self.renew(token:)
      return nil if token.blank?

      decoded = decode(token:)
      user_id = decoded["sub"]
      extra = decoded.except(*non_extra_attributes)

      encode(user_id:, **extra)
    end

    private_class_method

    def self.non_extra_attributes
      ["sub", "exp", "alg"]
    end

    def self.payload(user: nil, user_id: nil, **extra)
      {
        sub: user_id || user.id,
        exp: Time.current.to_i + THREE_HOURS
      }.merge(extra)
    end
  end
end
