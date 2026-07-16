# frozen_string_literal: true

module CustomerPortal
  class GenerateUrlService < BaseService
    Result = BaseResult[:url]

    def initialize(customer:)
      @customer = customer

      super
    end

    def call
      return result.not_found_failure!(resource: "customer") if customer.blank?

      public_authenticator = ActiveSupport::MessageVerifier.new(ENV["SECRET_KEY_BASE"])
      message = public_authenticator.generate(customer.id, expires_in: 12.hours)

      result.url = "#{ENV["LAGO_FRONT_URL"]}/customer-portal/#{message}"

      result
    end

    private

    attr_reader :customer
  end
end
