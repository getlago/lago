# frozen_string_literal: true

class PaymentMethod < ApplicationRecord
  include PaperTrailTraceable
  include Discard::Model

  self.discard_column = :deleted_at
  default_scope -> { kept }

  scope :default, -> { where(is_default: true) }

  belongs_to :organization
  belongs_to :customer, -> { with_discarded }
  belongs_to :payment_provider, optional: true, class_name: "PaymentProviders::BaseProvider"
  belongs_to :payment_provider_customer, optional: true, class_name: "PaymentProviderCustomers::BaseCustomer"

  PAYMENT_METHOD_TYPES = {
    provider: "provider",
    manual: "manual"
  }.freeze

  validates :provider_method_id, presence: true
  validates :is_default, inclusion: {in: [true, false]}

  def payment_provider_type
    payment_provider&.payment_type
  end
end

# == Schema Information
#
# Table name: payment_methods
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  deleted_at                   :datetime
#  details                      :jsonb            not null
#  is_default                   :boolean          default(FALSE), not null
#  provider_method_type         :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  customer_id                  :uuid             not null
#  organization_id              :uuid             not null
#  payment_provider_customer_id :uuid
#  payment_provider_id          :uuid
#  provider_method_id           :string           not null
#
# Indexes
#
#  index_payment_methods_on_customer_id                            (customer_id)
#  index_payment_methods_on_organization_id                        (organization_id)
#  index_payment_methods_on_payment_provider_customer_id           (payment_provider_customer_id)
#  index_payment_methods_on_payment_provider_id                    (payment_provider_id)
#  index_payment_methods_on_provider_customer_and_provider_method  (payment_provider_customer_id,provider_method_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_methods_on_provider_method_type                   (provider_method_type)
#  unique_default_payment_method_per_customer                      (customer_id) UNIQUE WHERE ((is_default = true) AND (deleted_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_provider_customer_id => payment_provider_customers.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
