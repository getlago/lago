# frozen_string_literal: true

module Organizations
  module Sluggable
    extend ActiveSupport::Concern

    SLUG_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/

    RESERVED_SLUGS = %w[
      auth login sign-up forgot-password reset-password invitation
      customer-portal 404 forbidden api admin graphql webhooks google okta
      settings new design-system devtool
      customers customer plans plan invoices invoice subscriptions
      coupons coupon add-ons add-on billable-metrics billable-metric
      credit-notes analytics analytics-v2 forecasts payments payment
      features feature tax webhook api-keys create update duplicate
    ].freeze

    included do
      validates :slug,
        presence: true,
        uniqueness: true,
        length: {minimum: 3, maximum: 40},
        format: {with: SLUG_FORMAT},
        exclusion: {in: RESERVED_SLUGS},
        if: -> { new_record? || slug_changed? }

      before_validation :generate_slug, on: :create
    end

    private

    def generate_slug
      return if slug.present?

      candidate = ActiveSupport::Inflector.transliterate(name.to_s)
        .parameterize
        .tr("_", "-")
        .gsub(/-{2,}/, "-")
        .truncate(40, omission: "")
        .gsub(/\A-|-\z/, "")

      if candidate.length < 3 || candidate.match?(/\A\d+\z/) || RESERVED_SLUGS.include?(candidate)
        loop do
          candidate = "org-#{SecureRandom.alphanumeric(5).downcase}"
          break unless self.class.exists?(slug: candidate)
        end
      else
        base = candidate.truncate(36, omission: "").delete_suffix("-")
        while self.class.exists?(slug: candidate)
          suffix = SecureRandom.alphanumeric(3).downcase
          candidate = "#{base}-#{suffix}"
        end
      end

      self.slug = candidate
    end
  end
end
