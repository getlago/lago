import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { DateTime } from 'luxon'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTES_TAB_ROUTE } from '~/core/router'
import {
  GetOrderForEditQuery,
  OrderExecutionModeEnum,
  useGetOrderForEditQuery,
  useUpdateOrderMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useAppForm } from '~/hooks/forms/useAppform'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildOrderHeader } from './common/buildOrderHeader'
import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import {
  buildUpdateOrderInput,
  EditOrderFormValues,
  editOrderValidationSchema,
} from './editOrder/validationSchema'

export const EDIT_ORDER_CLOSE_BUTTON_TEST_ID = 'edit-order-close-button'
export const EDIT_ORDER_CANCEL_BUTTON_TEST_ID = 'edit-order-cancel-button'
export const EDIT_ORDER_SUBMIT_BUTTON_TEST_ID = 'edit-order-submit-button'
export const EDIT_ORDER_EXECUTION_TYPE_TEST_ID = 'edit-order-execution-type'
export const EDIT_ORDER_PREVIEW_TEST_ID = 'edit-order-preview'

gql`
  query getOrderForEdit($id: ID!) {
    order(id: $id) {
      id
      number
      status
      orderType
      executeAt
      executionMode
      customer {
        id
        name
        displayName
      }
      orderForm {
        id
        number
        quote {
          ...QuoteDetailItem
        }
      }
    }
  }
`

gql`
  mutation updateOrder($input: UpdateOrderInput!) {
    updateOrder(input: $input) {
      id
      executeAt
      executionMode
    }
  }
`

type EditOrderFormContentProps = {
  order?: GetOrderForEditQuery['order']
  loading: boolean
}

/**
 * The form is split from the query so it can be remounted (via `key` on the
 * order id) once the order is loaded. This lets `defaultValues` be seeded from
 * the fetched order at the form's first render — the field components then
 * mount already displaying the order's values, instead of mounting empty and
 * being patched by a post-load `reset()` (which doesn't reliably propagate to
 * the inputs once they've mounted uncontrolled).
 */
const EditOrderFormContent = ({ order, loading }: EditOrderFormContentProps) => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { orderId } = useParams()
  const centralizedDialog = useCentralizedDialog()

  const [updateOrderMutation] = useUpdateOrderMutation({
    refetchQueries: ['getOrders'],
  })

  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: order?.orderForm?.quote?.currentVersion,
        customer: order?.orderForm?.quote?.customer,
        images: (order?.orderForm?.quote?.images ?? {}) as Record<string, string>,
      }),
    [
      order?.orderForm?.quote?.currentVersion,
      order?.orderForm?.quote?.customer,
      order?.orderForm?.quote?.images,
    ],
  )

  const orderNumber = order?.number ?? ''

  const header = buildOrderHeader({ number: order?.number }, translate)

  const closeRedirection = () => {
    goBack(generatePath(QUOTES_TAB_ROUTE, { tab: QuotesTabsOptionsEnum.orders }))
  }

  const defaultValues: EditOrderFormValues = {
    executionMode: order?.executionMode ?? undefined,
    executeAt: order?.executeAt ?? undefined,
  }

  const form = useAppForm({
    defaultValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: editOrderValidationSchema },
    onSubmit: async ({ value }) => {
      if (!orderId) return

      const result = await updateOrderMutation({
        variables: { input: buildUpdateOrderInput(orderId, value) },
      })

      if (result.data?.updateOrder) {
        addToast({ severity: 'success', translateKey: 'text_1782723591984c30uudt9ma9' })

        closeRedirection()
      }
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)

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

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate('text_178272359198433nj9yyhjt2', { orderNumber })}
        </Typography>
        <Button
          data-test={EDIT_ORDER_CLOSE_BUTTON_TEST_ID}
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
                  data-test={EDIT_ORDER_CANCEL_BUTTON_TEST_ID}
                  variant="quaternary"
                  onClick={onClose}
                >
                  {translate('text_6411e6b530cb47007488b027')}
                </Button>
                <Button
                  data-test={EDIT_ORDER_SUBMIT_BUTTON_TEST_ID}
                  variant="primary"
                  onClick={() => form.handleSubmit()}
                >
                  {translate('text_17827235919844cwbnt9ltfe')}
                </Button>
              </>
            )
          }
        >
          {loading || !order ? (
            <FormLoadingSkeleton id="edit-order" />
          ) : (
            <div className="flex flex-col gap-12">
              <div className="flex flex-col gap-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_178272359198433nj9yyhjt2', { orderNumber: order.number })}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_178272359198410yt5vl9ki4')}
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
                      {order.number}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_65201c5a175a4b0238abf29a')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {order.customer.displayName}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1781686594125ilr4k8xhb5m')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {order.orderType
                        ? translate(getQuoteOrderTypeTranslationKey(order.orderType))
                        : ''}
                    </Typography>
                  </div>
                  <div className="flex flex-col">
                    <Typography variant="caption" color="grey600">
                      {translate('text_1779695273381h7tmhdzrv48')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {`${order.orderForm.quote.number} - v${order.orderForm.quote.currentVersion.version}`}
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
                      dataTest={EDIT_ORDER_EXECUTION_TYPE_TEST_ID}
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
                      placement="top-end"
                      minDate={DateTime.now().plus({ days: 1 }).startOf('day')}
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
              dataTest={EDIT_ORDER_PREVIEW_TEST_ID}
              loading={loading}
              header={header}
              hasContent={!!order?.orderForm?.quote?.currentVersion?.content}
              previewProps={previewProps}
            />
          </div>
        </Side>
      </div>
    </div>
  )
}

const EditOrder = () => {
  const { translate } = useInternationalization()
  const { orderId } = useParams()

  const { data, loading, error } = useGetOrderForEditQuery({
    variables: { id: orderId || '' },
    skip: !orderId,
  })

  const order = data?.order

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

  // Keying on the order id remounts the form once the order is loaded, so the
  // form's defaultValues are seeded from the fetched order at first render.
  return <EditOrderFormContent key={order?.id ?? 'pending'} order={order} loading={loading} />
}

export default EditOrder
