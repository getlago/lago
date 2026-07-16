# frozen_string_literal: true

module PaymentProviders
  class BaseProvider < ApplicationRecord
    include PaperTrailTraceable
    include SecretsStorable
    include SettingsStorable
    include Discard::Model

    self.discard_column = :deleted_at
    default_scope -> { kept }

    self.table_name = "payment_providers"

    belongs_to :organization

    has_many :payment_provider_customers,
      dependent: :nullify,
      class_name: "PaymentProviderCustomers::BaseCustomer",
      foreign_key: :payment_provider_id

    has_many :customers, through: :payment_provider_customers
    has_many :payments, dependent: :nullify, foreign_key: :payment_provider_id
    has_many :payment_methods, dependent: :nullify, foreign_key: :payment_provider_id
    has_many :refunds, dependent: :nullify, foreign_key: :payment_provider_id

    validates :code, uniqueness: {conditions: -> { kept }, scope: :organization_id}
    validates :name, presence: true

    settings_accessors :webhook_secret, :success_redirect_url

    def determine_payment_status(payment_status)
      return :processing if self.class::PROCESSING_STATUSES.include?(payment_status)
      return :succeeded if self.class::SUCCESS_STATUSES.include?(payment_status)
      return :failed if self.class::FAILED_STATUSES.include?(payment_status)

      payment_status
    end
  end
end

# == Schema Information
#
# Table name: payment_providers
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  deleted_at      :datetime
#  name            :string           not null
#  secrets         :string
#  settings        :jsonb            not null
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_payment_providers_on_code_and_organization_id  (code,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_providers_on_organization_id           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
