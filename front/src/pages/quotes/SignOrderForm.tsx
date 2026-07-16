import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { DateTime } from 'luxon'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { DocumentUploader } from '~/components/form/DocumentUploader'
import { addToast } from '~/core/apolloClient'
import { QuoteDetailsTabsOptionsEnum, QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTE_DETAILS_ROUTE, QUOTES_TAB_ROUTE, useNavigate } from '~/core/router'
import {
  OrderExecutionModeEnum,
  useGetOrderFormForSignQuery,
  useMarkOrderFormAsSignedMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildOrderFormHeader } from './common/buildOrderFormHeader'
import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import {
  buildSignOrderFormInput,
  signOrderFormDefaultValues,
  signOrderFormValidationSchema,
} from './signOrderForm/validationSchema'

export const SIGN_ORDER_FORM_CLOSE_BUTTON_TEST_ID = 'sign-order-form-close-button'
export const SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID = 'sign-order-form-cancel-button'
export const SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID = 'sign-order-form-submit-button'
export const SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID = 'sign-order-form-execution-type'
export const SIGN_ORDER_FORM_ALERT_TEST_ID = 'sign-order-form-alert'
export const SIGN_ORDER_FORM_PREVIEW_TEST_ID = 'sign-order-form-preview'

const MAX_FILE_SIZE_IN_MB = 10 // 10MB
const MB_TO_BYTES = 1024 * 1024

gql`
  query getOrderFormForSign($id: ID!) {
    orderForm(id: $id) {
      id
      number
      status
      createdAt
      expiresAt
      customer {
        id
        name
        displayName
      }
      quote {
        ...QuoteDetailItem
      }
    }
  }
`

gql`
  mutation markOrderFormAsSigned($input: MarkOrderFormAsSignedInput!) {
    markOrderFormAsSigned(input: $input) {
      id
      status
    }
  }
`

const SignOrderForm = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { orderFormId } = useParams()
  const navigate = useNavigate()
  const centralizedDialog = useCentralizedDialog()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const { data, loading, error } = useGetOrderFormForSignQuery({
    variables: { id: orderFormId || '' },
    skip: !orderFormId,
  })

  const orderForm = data?.orderForm

  const [markOrderFormAsSignedMutation] = useMarkOrderFormAsSignedMutation({
    refetchQueries: ['getOrderForms'],
  })

  // Single source of truth for preview inputs (shared with the PDF renderer).
  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: orderForm?.quote?.currentVersion,
        customer: orderForm?.quote?.customer,
        images: (orderForm?.quote?.images ?? {}) as Record<string, string>,
      }),
    [orderForm?.quote?.currentVersion, orderForm?.quote?.customer, orderForm?.quote?.images],
  )

  const orderFormNumber = orderForm?.number ?? ''

  const header = buildOrderFormHeader(
    { number: orderForm?.number, expiresAt: orderForm?.expiresAt },
    translate,
    (iso) => intlFormatDateTimeOrgaTZ(iso).date,
  )

  const form = useAppForm({
    defaultValues: signOrderFormDefaultValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: signOrderFormValidationSchema },
    onSubmit: async ({ value }) => {
      const quoteId = orderForm?.quote?.id

      if (!orderFormId || !quoteId) return

      const result = await markOrderFormAsSignedMutation({
        variables: { input: buildSignOrderFormInput(orderFormId, value) },
      })

      if (result.data?.markOrderFormAsSigned) {
        addToast({ severity: 'success', translateKey: 'text_1781686594125pop15l3s7yw' })

        navigate(
          generatePath(QUOTE_DETAILS_ROUTE, {
            quoteId,
            tab: QuoteDetailsTabsOptionsEnum.orderForms,
          }),
        )
      }
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)

  const closeRedirection = () => {
    goBack(generatePath(QUOTES_TAB_ROUTE, { tab: QuotesTabsOptionsEnum.orderForms }))
  }

  const onClose = () => {
    if (!isDirty) {
      closeRedirection()

      return
    }

    centralizedDialog.open({
      title: translate('text_665deda4babaf700d603ea13'),
      description: translate('text_665dedd557dc3c00c62eb83d'),
      actionText: translate('text_645388d5bdbd7b00abffa033'),
      colorVariant: 'danger',
      onAction: () => closeRedirection(),
    })
  }

  if (error) {
    return (
      <GenericPlaceholder
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
          {translate('text_1781686594125csy9lu7em4h', { orderFormNumber })}
        </Typography>
        <Button
          data-test={SIGN_ORDER_FORM_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={onClose}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main
          footer={
            !loading && (
              <>
                <Button
                  data-test={SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID}
                  variant="quaternary"
                  onClick={onClose}
                >
                  {translate('text_6411e6b530cb47007488b027')}
                </Button>
                <Button
                  data-test={SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID}
                  variant="primary"
                  onClick={() => form.handleSubmit()}
                >
                  {translate('text_1781686594125upfeikkemuy')}
                </Button>
              </>
            )
          }
        >
          {loading ? (
            <FormLoadingSkeleton id="sign-order-form" />
          ) : (
            <div className="flex flex-col gap-12">
              <Alert data-test={SIGN_ORDER_FORM_ALERT_TEST_ID} type="info">
                <Typography className="text-grey-700">
                  {translate('text_1781686594125tgfd5ypl1h6')}
                </Typography>
              </Alert>

              <div className="flex flex-col gap-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_1781686594125csy9lu7em4h', {
                    orderFormNumber: orderForm?.number,
                  })}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_178168659412503g50mhn67p')}
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
                </div>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1781686594125jxy4tktm5sv')}
                </Typography>

                <form.AppField name="executionMode">
                  {(field) => (
                    <field.ComboBoxField
                      dataTest={SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID}
                      label={translate('text_17816865941251f6epdwidgk')}
                      placeholder={translate('text_1781686594125cgczfi8sgbt')}
                      disableClearable
                      data={[
                        {
                          value: OrderExecutionModeEnum.ExecuteInLago,
                          label: translate('text_1781686594125wc395bj9cul'),
                          description: translate('text_17817078224635v32b58mejt'),
                        },
                        {
                          value: OrderExecutionModeEnum.OrderOnly,
                          label: translate('text_1781686594125ibfjmzae7cy'),
                          description: translate('text_17817078224637p2veq3bqwe'),
                        },
                      ]}
                    />
                  )}
                </form.AppField>

                <form.AppField name="executeAt">
                  {(field) => (
                    <field.DatePickerField
                      label={translate('text_17816865941256grf5qs2924')}
                      description={translate('text_1781869435540pqqpg9kc005')}
                      placeholder={translate('text_17816865941253r8yqeoibh1')}
                      minDate={DateTime.now().plus({ days: 1 }).startOf('day')}
                    />
                  )}
                </form.AppField>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1781686594125byrh8211ju7')}
                </Typography>
                <form.AppField name="signedDocument">
                  {(field) => (
                    <DocumentUploader
                      value={field.state.value ?? null}
                      onChange={(value) => field.handleChange(value ?? undefined)}
                      accept="application/pdf,image/jpeg,image/png"
                      acceptedMimeTypes={['application/pdf', 'image/jpeg', 'image/png']}
                      maxSize={MAX_FILE_SIZE_IN_MB * MB_TO_BYTES}
                      description={translate('text_1781686594125j2s47tpkzvo')}
                      invalidTypeError={translate('text_1781686594125m4b2ej18zyb')}
                      tooLargeError={translate('text_1781686594125tj83pbtkkad')}
                    />
                  )}
                </form.AppField>
              </div>
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={SIGN_ORDER_FORM_PREVIEW_TEST_ID}
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

export default SignOrderForm
