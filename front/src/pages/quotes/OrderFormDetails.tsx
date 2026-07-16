import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTES_TAB_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildOrderFormHeader } from './common/buildOrderFormHeader'
import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import { useOrderFormDetails } from './hooks/useOrderFormDetails'

export const ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID = 'order-form-details-close-button'
export const ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID = 'order-form-details-description'
export const ORDER_FORM_DETAILS_ERROR_TEST_ID = 'order-form-details-error'
export const ORDER_FORM_DETAILS_PREVIEW_TEST_ID = 'order-form-details-preview'
export const ORDER_FORM_DETAILS_ATTACHMENTS_TEST_ID = 'order-form-details-attachments'

const OrderFormDetails = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { orderFormId } = useParams()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const { orderForm, loading, error } = useOrderFormDetails(orderFormId)

  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: orderForm?.quote?.currentVersion,
        customer: orderForm?.customer,
        images: (orderForm?.quote?.images ?? {}) as Record<string, string>,
      }),
    [orderForm?.quote?.currentVersion, orderForm?.customer, orderForm?.quote?.images],
  )

  const orderFormNumber = orderForm?.number ?? ''

  const header = buildOrderFormHeader(
    { number: orderForm?.number, expiresAt: orderForm?.expiresAt },
    translate,
    (iso) => intlFormatDateTimeOrgaTZ(iso).date,
  )

  const onClose = () => {
    goBack(generatePath(QUOTES_TAB_ROUTE, { tab: QuotesTabsOptionsEnum.orderForms }))
  }

  if (error) {
    return (
      <GenericPlaceholder
        data-test={ORDER_FORM_DETAILS_ERROR_TEST_ID}
        className="pt-12"
        title={translate('text_634812d6f16b31ce5cbf4126')}
        subtitle={translate('text_634812d6f16b31ce5cbf4128')}
        buttonTitle={translate('text_634812d6f16b31ce5cbf412a')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate('text_17828094623997l9tqj385k5', { orderFormNumber })}
        </Typography>
        <Button
          data-test={ORDER_FORM_DETAILS_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={onClose}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main>
          {loading ? (
            <FormLoadingSkeleton id="order-form-details" />
          ) : (
            <div className="flex flex-col gap-12">
              <div className="flex flex-col gap-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_17828094623997l9tqj385k5', { orderFormNumber })}
                </Typography>
                <Typography data-test={ORDER_FORM_DETAILS_DESCRIPTION_TEST_ID} color="grey600">
                  {translate('text_1782821511108j6cgg7ioq23')}
                </Typography>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1781686594125zdfs2dn7aef')}
                </Typography>
                <div className="grid grid-cols-2 gap-4">
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1781686594125hr5o1ucifso')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {orderForm?.number}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_65201c5a175a4b0238abf29a')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {orderForm?.customer.displayName}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1781686594125ilr4k8xhb5m')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {orderForm?.quote.orderType
                        ? translate(getQuoteOrderTypeTranslationKey(orderForm.quote.orderType))
                        : ''}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1779695273381h7tmhdzrv48')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {orderForm
                        ? `${orderForm.quote.number} - v${orderForm.quote.currentVersion.version}`
                        : ''}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1782808811242x7jvelxo3kr')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {orderForm?.expiresAt
                        ? intlFormatDateTimeOrgaTZ(orderForm.expiresAt).date
                        : '-'}
                    </Typography>
                  </div>
                </div>
              </div>

              {orderForm?.signedDocumentUrl && (
                <div
                  className="flex flex-col gap-6"
                  data-test={ORDER_FORM_DETAILS_ATTACHMENTS_TEST_ID}
                >
                  <Typography variant="subhead1">
                    {translate('text_1781686594125byrh8211ju7')}
                  </Typography>
                  <div>
                    <Button
                      variant="quaternary"
                      startIcon="paperclip"
                      endIcon="outside"
                      onClick={() => window.open(orderForm.signedDocumentUrl ?? '', '_blank')}
                    >
                      {translate('text_178280881124242ngphx36je')}
                    </Button>
                  </div>
                </div>
              )}
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={ORDER_FORM_DETAILS_PREVIEW_TEST_ID}
              loading={loading}
              header={header}
              hasContent={!!orderForm?.quote?.currentVersion?.content}
              previewProps={previewProps}
            />
          </div>
        </Side>
      </div>
    </div>
  )
}

export default OrderFormDetails
