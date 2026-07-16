# frozen_string_literal: true

module PaymentProviderCustomers
  class StripeCustomer < BaseCustomer
    PAYMENT_METHODS_WITH_SETUP = %w[card sepa_debit us_bank_account bacs_debit link boleto].freeze
    PAYMENT_METHODS_WITHOUT_SETUP = %w[crypto customer_balance].freeze
    PAYMENT_METHODS = (PAYMENT_METHODS_WITH_SETUP + PAYMENT_METHODS_WITHOUT_SETUP).freeze

    validates :provider_payment_methods, presence: true
    validate :allowed_provider_payment_methods
    validate :link_payment_method_can_exist_only_with_card
    validate :customer_balance_must_be_exclusive

    settings_accessors :payment_method_id

    def provider_payment_methods
      get_from_settings("provider_payment_methods")
    end

    def provider_payment_methods_with_setup
      provider_payment_methods & PAYMENT_METHODS_WITH_SETUP
    end

    def provider_payment_methods_require_setup?
      provider_payment_methods_with_setup.present?
    end

    def provider_payment_methods=(provider_payment_methods)
      push_to_settings(key: "provider_payment_methods", value: provider_payment_methods.to_a)
    end

    private

    def allowed_provider_payment_methods
      return if (provider_payment_methods - PAYMENT_METHODS).blank?

      errors.add(:provider_payment_methods, :invalid)
    end

    def link_payment_method_can_exist_only_with_card
      return if provider_payment_methods.exclude?("link") || provider_payment_methods.include?("card")

      errors.add(:provider_payment_methods, :invalid)
    end

    def customer_balance_must_be_exclusive
      return unless provider_payment_methods.include?("customer_balance")
      return if provider_payment_methods == ["customer_balance"]

      errors.add(:provider_payment_methods, "customer_balance cannot be combined with other payment methods")
    end
  end
end

# == Schema Information
#
# Table name: payment_provider_customers
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  deleted_at           :datetime
#  settings             :jsonb            not null
#  type                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  customer_id          :uuid             not null
#  organization_id      :uuid             not null
#  payment_provider_id  :uuid
#  provider_customer_id :string
#
# Indexes
#
#  index_payment_provider_customers_on_customer_id_and_type  (customer_id,type) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_provider_customers_on_organization_id       (organization_id)
#  index_payment_provider_customers_on_payment_provider_id   (payment_provider_id)
#  index_payment_provider_customers_on_provider_customer_id  (provider_customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
