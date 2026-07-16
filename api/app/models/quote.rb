# frozen_string_literal: true

class Quote < ApplicationRecord
  include Sequenced

  ORDER_TYPES = {
    subscription_creation: "subscription_creation",
    subscription_amendment: "subscription_amendment",
    one_off: "one_off"
  }.freeze

  QUOTE_NUMBER_REGEX = /\AQT-\d{4}-\d{4,}\z/

  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  IMAGE_MAX_SIZE = 5.megabytes

  before_save :ensure_number

  belongs_to :organization
  belongs_to :customer
  belongs_to :subscription, optional: true

  has_many :quote_owners, dependent: :destroy
  has_many :owners, through: :quote_owners, source: :user, class_name: "User"

  has_many :versions, -> { order(sequential_id: :desc) }, class_name: "QuoteVersion"
  has_one :current_version, -> { order(sequential_id: :desc) }, class_name: "QuoteVersion"
  has_many :order_forms, through: :versions

  has_many_attached :images

  enum :order_type, ORDER_TYPES,
    instance_methods: false,
    validate: true

  validates :subscription_id,
    presence: true,
    if: -> { order_type == "subscription_amendment" }

  validates :images,
    content_type: IMAGE_CONTENT_TYPES,
    size: {less_than: IMAGE_MAX_SIZE}

  sequenced(
    scope: ->(quote) { quote.organization.quotes },
    lock_key: ->(quote) { quote.organization_id }
  )

  private

  def ensure_number
    return if number.present?
    return if sequential_id.blank?

    time = created_at || Time.current
    formatted_sequential_id = format("%04d", sequential_id)
    self.number = "QT-#{time.strftime("%Y")}-#{formatted_sequential_id}"
  end
end

# == Schema Information
#
# Table name: quotes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  number          :string           not null
#  order_type      :enum             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  customer_id     :uuid             not null
#  organization_id :uuid             not null
#  sequential_id   :integer          not null
#  subscription_id :uuid
#
# Indexes
#
#  index_quotes_on_customer_id                        (customer_id)
#  index_quotes_on_subscription_id                    (subscription_id)
#  index_unique_quotes_on_organization_number         (organization_id,number) UNIQUE
#  index_unique_quotes_on_organization_sequential_id  (organization_id,sequential_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
