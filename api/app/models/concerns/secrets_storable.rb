# frozen_string_literal: true

module SecretsStorable
  extend ActiveSupport::Concern

  included do
    encrypts :secrets
  end

  class_methods do
    def secrets_accessors(*method_names)
      method_names.each do |name|
        define_method(name) do
          get_from_secrets(name.to_s)
        end

        define_method(:"#{name}=") do |value|
          push_to_secrets(key: name.to_s, value:)
        end
      end
    end
  end

  def secrets_json
    JSON.parse(secrets || "{}")
  end

  def push_to_secrets(key:, value:)
    self.secrets = secrets_json.merge(key => value).to_json
  end

  def get_from_secrets(key)
    secrets_json[key.to_s]
  end
end
