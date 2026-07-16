# frozen_string_literal: true

class OrganizationMailer < ApplicationMailer
  def authentication_methods_updated
    @organization = params[:organization]
    @user = params[:user]
    @additions = params[:additions]
    @deletions = params[:deletions]

    return if @organization.nil? || @user.nil?
    return if @additions.empty? && @deletions.empty?

    I18n.locale = @organization.document_locale

    mail(
      bcc: @organization.admins.map(&:email),
      from: ENV["LAGO_FROM_EMAIL"],
      reply_to: email_address_with_name(@organization.from_email_address, @organization.name),
      subject: I18n.t(
        "email.organization.authentication_methods_updated.subject"
      )
    )
  end
end
