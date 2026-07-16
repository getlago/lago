# frozen_string_literal: true

class ApiKeyMailerPreview < BasePreviewMailer
  def rotated
    api_key = FactoryBot.create(:api_key)
    ApiKeyMailer.with(api_key:).rotated
  end

  def created
    api_key = FactoryBot.create(:api_key)
    ApiKeyMailer.with(api_key:).created
  end

  def destroyed
    api_key = FactoryBot.create(:api_key)
    ApiKeyMailer.with(api_key:).destroyed
  end
end
