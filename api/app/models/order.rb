# frozen_string_literal: true

class Order < ApplicationRecord
  include Sequenced

  STATUSES = {
    created: "created",
    executed: "executed"
  }.freeze

  EXECUTION_MODES = {
    execute_in_lago: "execute_in_lago",
    order_only: "order_only"
  }.freeze

  before_save :ensure_number

  belongs_to :organization
  belongs_to :customer
  belongs_to :order_form
  has_one :quote_version, through: :order_form
  has_one :quote, through: :quote_version

  enum :status, STATUSES,
    default: :created,
    validate: true
  enum :execution_mode, EXECUTION_MODES,
    instance_methods: false,
    validate: {allow_nil: true}

  validates :execution_mode, presence: true, if: -> { executed? || execute_at.present? }

  delegate :order_type, to: :quote
  delegate :currency, to: :quote_version

  # TODO: migrate this to a real column when billing items validation is ready
  def billing_snapshot
    quote_version.billing_items
  end

  def self.ransackable_attributes(_ = nil)
    %w[number]
  end

  sequenced(
    scope: ->(order) { order.organization.orders },
    lock_key: ->(order) { order.organization_id }
  )

  private

  def ensure_number
    return if number.present?
    return if sequential_id.blank?

    time = created_at || Time.current
    formatted_sequential_id = format("%04d", sequential_id)
    self.number = "OR-#{time.strftime("%Y")}-#{formatted_sequential_id}"
  end
end

# == Schema Information
#
# Table name: orders
# Database name: primary
#
#  id              :uuid             not null, primary key
#  execute_at      :datetime
#  executed_at     :datetime
#  execution_mode  :enum
#  number          :string           not null
#  status          :enum             default("created"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  customer_id     :uuid             not null
#  order_form_id   :uuid             not null
#  organization_id :uuid             not null
#  sequential_id   :integer          not null
#
# Indexes
#
#  index_orders_on_customer_id                        (customer_id)
#  index_orders_on_order_form_id                      (order_form_id) UNIQUE
#  index_orders_on_organization_id_and_created_at     (organization_id,created_at)
#  index_orders_on_organization_id_and_status         (organization_id,status)
#  index_unique_orders_on_organization_number         (organization_id,number) UNIQUE
#  index_unique_orders_on_organization_sequential_id  (organization_id,sequential_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (order_form_id => order_forms.id)
#  fk_rails_...  (organization_id => organizations.id)
#
