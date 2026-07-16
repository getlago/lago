# frozen_string_literal: true

module PaymentProviderCustomers
  class AdyenCustomer < BaseCustomer
    settings_accessors :payment_method_id
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
