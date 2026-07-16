# frozen_string_literal: true

class BaseService
  include AfterCommitEverywhere

  # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  class_attribute :middlewares, instance_writer: false, default: []
  # rubocop:enable ThreadSafety/ClassAndModuleAttributes

  class FailedResult < StandardError
    attr_reader :result, :original_error

    def initialize(result, message, original_error: nil)
      @result = result
      @original_error = original_error

      super(message)
    end
  end

  class ThrottlingError < StandardError
    attr_reader :provider_name

    def initialize(provider_name: nil)
      @provider_name = provider_name

      super(message)
    end

    def message
      "Service #{provider_name} is not available. Try again later."
    end
  end

  class NotFoundFailure < FailedResult
    attr_reader :resource

    def initialize(result, resource:)
      @resource = resource

      super(result, error_code)
    end

    def error_code
      "#{resource}_not_found"
    end
  end

  class MethodNotAllowedFailure < FailedResult
    attr_reader :code

    def initialize(result, code:)
      @code = code

      super(result, code)
    end
  end

  class ValidationFailure < FailedResult
    attr_reader :messages

    def initialize(result, messages:)
      @messages = messages

      super(result, format_messages)
    end

    private

    def format_messages
      "Validation errors: #{messages.to_json}"
    end
  end

  class ServiceFailure < FailedResult
    attr_reader :code, :error_message

    def initialize(result, code:, error_message:, original_error: nil)
      @code = code
      @error_message = error_message

      super(result, "#{code}: #{error_message}", original_error:)
    end
  end

  class NonRetryableFailure < ServiceFailure; end

  class UnknownTaxFailure < FailedResult
    attr_reader :code, :error_message

    def initialize(result, code:, error_message:)
      @code = code
      @error_message = error_message

      super(result, "#{code}: #{error_message}")
    end
  end

  class ForbiddenFailure < FailedResult
    attr_reader :code

    def initialize(result, code:)
      @code = code

      super(result, code)
    end
  end

  class UnauthorizedFailure < FailedResult
    def initialize(result, message:)
      super(result, message)
    end
  end

  class ProviderFailure < FailedResult
    attr_reader :provider

    def initialize(result, provider:, error:)
      @provider = provider
      super(result, nil, original_error: error)
    end
  end

  class ThirdPartyFailure < FailedResult
    attr_reader :third_party, :error_code, :error_message

    def initialize(result, third_party:, error_code:, error_message:)
      @third_party = third_party
      @error_message = error_message
      @error_code = error_code

      super(result, "#{third_party}: #{error_code} - #{error_message}")
    end
  end

  class TooManyProviderRequestsFailure < FailedResult
    attr_reader :provider_name, :error

    def initialize(result, provider_name:, error:)
      @provider_name = provider_name
      @error = error

      super(result, error.message, original_error: error)
    end
  end

  # DEPRECATED: This is a legacy result class that should
  #             be replaced be defining a Result in every service, using the BaseResult
  class LegacyResult < OpenStruct
    include ::Result
  end

  Result = LegacyResult

  def self.activity_loggable(action:, record:, condition: -> { true }, after_commit: true)
    use(Middlewares::ActivityLogMiddleware, action:, record:, condition:, after_commit:)
  end

  # Register a new middleware
  def self.use(middleware_class, *args, on_conflict: :raise, **kwargs)
    existing_middleware = middlewares.map(&:first)

    if !existing_middleware.include?(middleware_class) || on_conflict == :append
      return self.middlewares += [[middleware_class, args, kwargs]]
    end

    # Middleware already exists
    case on_conflict
    when :raise
      raise Middlewares::AlreadyAddedError.new(middleware_class, self)
    when :replace
      self.middlewares[existing_middleware.index(middleware_class)] = [middleware_class, args, kwargs]
    when :ignore
      # Do nothing
    end
  end

  use(Middlewares::LogTracerMiddleware)
  use(Middlewares::DatadogMiddleware) if ENV["DD_AGENT_HOST"].present?

  def self.call(*, **, &)
    new(*, **).call_with_middlewares(&)
  end

  def self.call_async(*, **, &)
    LagoTracer.in_span("#{name}#call_async") do
      new(*, **).call_async(&)
    end
  end

  def self.call!(*, **, &)
    call(*, **, &).raise_if_error!
  end

  def initialize(args = nil)
    @result = self.class::Result.new
    @source = CurrentContext&.source
  end

  def call(**args, &block)
    raise NotImplementedError
  end

  def call!(*, &)
    call(*, &).raise_if_error!
  end

  def call_async(**args, &block)
    raise NotImplementedError
  end

  def call_with_middlewares(&block)
    chain = init_middlewares

    chain.call { call(&block) }
  end

  protected

  attr_writer :result

  private

  attr_reader :result, :source

  def api_context?
    source&.to_sym == :api
  end

  def graphql_context?
    source&.to_sym == :graphql
  end

  def at_time_zone(customer: "customers", billing_entity: "billing_entities")
    Utils::Timezone.at_time_zone_sql(customer:, billing_entity:)
  end

  def init_middlewares
    stack = lambda { |&block| block.call }

    # Initialize middlewares in reverse order (Rake like approach)
    self.class.middlewares.reverse_each do |middleware_klass, args, kwargs|
      current_stack = stack

      stack = lambda do |&block|
        middleware = middleware_klass.new(self, current_stack, *args, **kwargs)
        middleware.call(&block)
      end
    end

    stack
  end
end
