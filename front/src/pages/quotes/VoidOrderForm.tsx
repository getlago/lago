import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { QuoteDetailsTabsOptionsEnum, QuotesTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTE_DETAILS_ROUTE, QUOTES_TAB_ROUTE, useNavigate } from '~/core/router'
import { useGetOrderFormForVoidQuery, useVoidOrderFormMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getOrderFormStatusMapping } from './common/getOrderFormStatusMapping'
import { QuotePreviewCard } from './common/QuotePreviewCard'

export const VOID_ORDER_FORM_CLOSE_BUTTON_TEST_ID = 'void-order-form-close-button'
export const VOID_ORDER_FORM_VOID_BUTTON_TEST_ID = 'void-order-form-void-button'
export const VOID_ORDER_FORM_CANCEL_BUTTON_TEST_ID = 'void-order-form-cancel-button'
export const VOID_ORDER_FORM_ALERT_TEST_ID = 'void-order-form-alert'
export const VOID_ORDER_FORM_PREVIEW_TEST_ID = 'void-order-form-preview'

gql`
  query getOrderFormForVoid($id: ID!) {
    orderForm(id: $id) {
      id
      number
      status
      createdAt
      customer {
        id
        name
        displayName
        ...QuotePreviewCustomer
      }
      quote {
        id
        number
        images
        currentVersion {
          version
          ...QuotePreviewVersion
        }
      }
    }
  }
`

gql`
  mutation voidOrderForm($input: VoidOrderFormInput!) {
    voidOrderForm(input: $input) {
      id
      status
    }
  }
`

const VoidOrderForm = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { orderFormId } = useParams()
  const navigate = useNavigate()

  const { data, loading, error } = useGetOrderFormForVoidQuery({
    variables: { id: orderFormId || '' },
    skip: !orderFormId,
  })

  const orderForm = data?.orderForm

  const orderFormNumber = orderForm?.number ?? ''

  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: orderForm?.quote?.currentVersion,
        customer: orderForm?.customer,
        images: (orderForm?.quote?.images ?? {}) as Record<string, string>,
      }),
    [orderForm?.quote?.currentVersion, orderForm?.customer, orderForm?.quote?.images],
  )

  const header = {
    documentNumber: orderFormNumber,
    rows: [translate('text_1781778938224iupllzr5sgb', { orderFormNumber })],
  }

  const [voidOrderFormMutation] = useVoidOrderFormMutation({
    refetchQueries: ['getOrderForms'],
  })

  const onSubmit = async () => {
    const quoteId = orderForm?.quote?.id

    if (!orderFormId || !quoteId) return

    const result = await voidOrderFormMutation({
      variables: {
        input: {
          id: orderFormId,
        },
      },
    })

    if (result.data?.voidOrderForm) {
      addToast({
        severity: 'success',
        translateKey: 'text_1781625672232ia473jidiy8',
      })

      navigate(
        generatePath(QUOTE_DETAILS_ROUTE, {
          quoteId,
          tab: QuoteDetailsTabsOptionsEnum.orderForms,
        }),
      )
    }
  }

  const onClose = () => {
    goBack(
      generatePath(QUOTES_TAB_ROUTE, {
        tab: QuotesTabsOptionsEnum.orderForms,
      }),
    )
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
          {translate('text_1779715648584xw9xgemkv9y')}
        </Typography>
        <Button
          data-test={VOID_ORDER_FORM_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={() => onClose()}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main
          footer={
            !loading && (
              <>
                <Button
                  data-test={VOID_ORDER_FORM_CANCEL_BUTTON_TEST_ID}
                  variant="quaternary"
                  onClick={() => onClose()}
                >
                  {translate('text_6411e6b530cb47007488b027')}
                </Button>
                <Button
                  data-test={VOID_ORDER_FORM_VOID_BUTTON_TEST_ID}
                  variant="primary"
                  danger
                  onClick={() => onSubmit()}
                >
                  {translate('text_1779715648584xw9xgemkv9y')}
                </Button>
              </>
            )
          }
        >
          {loading ? (
            <FormLoadingSkeleton id="void-order-form" />
          ) : (
            <div className="flex flex-col gap-12">
              <Alert data-test={VOID_ORDER_FORM_ALERT_TEST_ID} type="warning">
                <Typography className="text-grey-700">
                  {translate('text_1779715648585ih339cvcfjx')}
                </Typography>
              </Alert>

              <div className="flex flex-col gap-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_1779715648585yngcc34h4kq', {
                    orderFormNumber: orderForm?.number,
                  })}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_17797156485853s6nzac3mll')}
                </Typography>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1779715648585ivakmu9pgk2')}
                </Typography>
                <Table
                  name="order-form-void-details"
                  data={orderForm ? [orderForm] : []}
                  containerSize={0}
                  columns={[
                    {
                      key: 'status',
                      title: translate('text_63ac86d797f728a87b2f9fa7'),
                      minWidth: 100,
                      content: ({ status }) => {
                        if (!status) return null

                        return <Status {...getOrderFormStatusMapping(status, translate)} />
                      },
                    },
                    {
                      key: 'number',
                      title: translate('text_1781624189693d7zcv2vog4c'),
                      maxSpace: true,
                      content: ({ number }) => number,
                    },
                    {
                      key: 'customer.displayName',
                      title: translate('text_65201c5a175a4b0238abf29a'),
                      maxSpace: true,
                      content: ({ customer }) => customer.displayName,
                    },
                    {
                      key: 'quote.number',
                      title: translate('text_1779695273381h7tmhdzrv48'),
                      minWidth: 140,
                      textAlign: 'right',
                      content: ({ quote }) => `${quote.number} - v${quote.currentVersion.version}`,
                    },
                  ]}
                />
              </div>
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={VOID_ORDER_FORM_PREVIEW_TEST_ID}
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

export default VoidOrderForm
