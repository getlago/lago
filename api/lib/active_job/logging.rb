# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"

module ActiveJob
  module Logging # :nodoc:
    extend ActiveSupport::Concern

    included do
      # rubocop:disable ThreadSafety/ClassAndModuleAttributes
      cattr_accessor :logger, default: ActiveSupport::Logger.new($stdout)
      class_attribute :log_arguments, instance_accessor: false, default: true
      # rubocop:enable ThreadSafety/ClassAndModuleAttributes
    end
  end
end
