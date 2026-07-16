# frozen_string_literal: true

class ApiKeyMailer < ApplicationMailer
  def rotated
    organization = params[:api_key].organization
    @organization_name = organization.name

    I18n.with_locale(:en) do
      mail(
        bcc: organization.admins.pluck(:email),
        from: ENV["LAGO_FROM_EMAIL"],
        subject: I18n.t("email.api_key.rotated.subject")
      )
    end
  end

  def created
    organization = params[:api_key].organization
    @organization_name = organization.name

    I18n.with_locale(:en) do
      mail(
        bcc: organization.admins.pluck(:email),
        from: ENV["LAGO_FROM_EMAIL"],
        subject: I18n.t("email.api_key.created.subject")
      )
    end
  end

  def destroyed
    organization = params[:api_key].organization
    @organization_name = organization.name

    I18n.with_locale(:en) do
      mail(
        bcc: organization.admins.pluck(:email),
        from: ENV["LAGO_FROM_EMAIL"],
        subject: I18n.t("email.api_key.destroyed.subject")
      )
    end
  end
end
