# frozen_string_literal: true

module LicenseHelper
  def lago_premium!
    License.instance_variable_set(:@premium, true)
    yield
    License.instance_variable_set(:@premium, false)
  end

  def premium_integration!(organization, premium_integration, &block)
    old_integrations = organization.premium_integrations
    organization.premium_integrations << premium_integration
    organization.save!

    lago_premium!(&block)

    organization.update! premium_integrations: old_integrations
  end
end
