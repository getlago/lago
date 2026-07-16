# frozen_string_literal: true

module Organizations
  module AuthenticationMethods
    extend ActiveSupport::Concern

    EMAIL_PASSWORD = "email_password"
    GOOGLE_OAUTH = "google_oauth"
    OKTA = "okta"

    FREE_AUTHENTICATION_METHODS = [EMAIL_PASSWORD, GOOGLE_OAUTH].freeze
    PREMIUM_AUTHENTICATION_METHODS = [OKTA].freeze
    AUTHENTICATION_METHODS = FREE_AUTHENTICATION_METHODS + PREMIUM_AUTHENTICATION_METHODS

    included do
      validates :authentication_methods, length: {minimum: 1}
      validates :authentication_methods, inclusion: {in: AUTHENTICATION_METHODS}

      FREE_AUTHENTICATION_METHODS.each do |method|
        define_method("#{method}_authentication_enabled?") do
          authentication_methods.include?(method)
        end

        define_method("enable_#{method}_authentication!") do
          return true if send("#{method}_authentication_enabled?")

          authentication_methods << method
          save!
        end
      end

      # NOTE: Authentication methods with the same name as the premium integration.
      PREMIUM_AUTHENTICATION_METHODS.each do |method|
        define_method("#{method}_authentication_enabled?") do
          send("#{method}_enabled?") && authentication_methods.include?(method)
        end

        define_method("enable_#{method}_authentication!") do
          return false unless send("#{method}_enabled?")
          return true if send("#{method}_authentication_enabled?")

          authentication_methods << method
          save!
        end
      end

      AUTHENTICATION_METHODS.each do |method|
        define_method("disable_#{method}_authentication!") do
          return false unless send("#{method}_authentication_enabled?")

          authentication_methods.delete(method)
          save!
        end
      end
    end
  end
end
