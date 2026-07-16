# frozen_string_literal: true

module PaymentProviderCustomers
  class BaseCustomer < ApplicationRecord
    include PaperTrailTraceable
    include SettingsStorable
    include Discard::Model

    self.discard_column = :deleted_at
    default_scope -> { kept }

    self.table_name = "payment_provider_customers"

    belongs_to :customer
    belongs_to :payment_provider, optional: true, class_name: "PaymentProviders::BaseProvider"
    belongs_to :organization

    has_many :payments
    has_many :payment_methods, foreign_key: :payment_provider_customer_id
    has_many :refunds, foreign_key: :payment_provider_customer_id

    validates :customer_id, uniqueness: {conditions: -> { where(deleted_at: nil) }, scope: :type}

    settings_accessors :provider_mandate_id, :sync_with_provider

    scope :by_provider_id_from_organization, ->(organization_id, provider_id) do
      joins(:customer)
        .where(customers: {organization_id: organization_id})
        .where(provider_customer_id: provider_id)
    end

    def provider_payment_methods
      nil
    end

    def require_provider_payment_id?
      true
    end

    def legacy_provider_method_id
      get_from_settings("payment_method_id") || get_from_settings("provider_mandate_id")
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
