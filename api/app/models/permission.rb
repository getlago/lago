# frozen_string_literal: true

module Permission
  extend self

  def permissions_hash(role = nil)
    role = role.to_s.downcase
    DATA.transform_values { |list| role == "admin" || list.include?(role) }
  end

  private

  def yaml_to_hash(filename)
    h = YAML.parse_file(Rails.root.join("config", filename)).to_ruby
    DottedHash.new(h, separator: ":").transform_values(&:to_a)
  end

  # rubocop:disable Layout/ClassStructure
  DATA = yaml_to_hash("permissions.yml").freeze
end
