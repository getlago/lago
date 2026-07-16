# frozen_string_literal: true

module WalletMetadataActions
  include Pagination
  extend ActiveSupport::Concern

  def metadata_create(wallet)
    result = ::Wallets::UpdateService.call(wallet:, params: metadata_params)

    if result.success?
      render_metadata
    else
      render_error_response(result)
    end
  end

  def metadata_update(wallet)
    result = ::Wallets::UpdateService.call(wallet:, partial_metadata: true, params: metadata_params)

    if result.success?
      render_metadata
    else
      render_error_response(result)
    end
  end

  def metadata_destroy(wallet)
    result = ::Wallets::UpdateService.call(wallet:, params: {metadata: nil})

    if result.success?
      render_metadata
    else
      render_error_response(result)
    end
  end

  def metadata_destroy_key(wallet)
    return not_found_error(resource: "metadata") unless wallet.metadata

    result = Metadata::DeleteItemKeyService.call(item: wallet.metadata, key: params[:key])

    if result.success?
      render_metadata
    else
      render_error_response(result)
    end
  end

  private

  def metadata_params
    params.permit(metadata: {}).to_h
  end

  def render_metadata
    render(json: {metadata: wallet.reload.metadata&.value})
  end
end
