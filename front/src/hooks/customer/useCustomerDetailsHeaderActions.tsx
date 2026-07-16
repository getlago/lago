import { RefObject } from 'react'
import { generatePath } from 'react-router-dom'

import { AddCouponToCustomerDialogRef } from '~/components/customers/AddCouponToCustomerDialog'
import { useDeleteCustomerDialog } from '~/components/customers/DeleteCustomerDialog'
import { MainHeaderAction } from '~/components/MainHeader/types'
import {
  CREATE_INVOICE_ROUTE,
  CREATE_SUBSCRIPTION,
  CREATE_WALLET_ROUTE,
  CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
  CUSTOMERS_LIST_ROUTE,
  UPDATE_CUSTOMER_ROUTE,
  useNavigate,
} from '~/core/router'
import { CustomerDetailsFragment, useGenerateCustomerPortalUrlMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDownloadFile } from '~/hooks/useDownloadFile'
import { useIsCustomerReadyForOverduePayment } from '~/hooks/useIsCustomerReadyForOverduePayment'
import { usePermissions } from '~/hooks/usePermissions'

const REQUEST_OVERDUE_PAYMENT_BUTTON_TEST_ID = 'request-overdue-payment-button'
const CUSTOMER_ACTIONS_BUTTON_TEST_ID = 'customer-actions'

interface UseCustomerDetailsHeaderActionsParams {
  customerId: string
  customer: CustomerDetailsFragment | undefined | null
  addCouponDialogRef: RefObject<AddCouponToCustomerDialogRef>
}

export function useCustomerDetailsHeaderActions({
  customerId,
  customer,
  addCouponDialogRef,
}: UseCustomerDetailsHeaderActionsParams): MainHeaderAction[] {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()
  const { handleDownloadFile } = useDownloadFile()
  const { openDeleteCustomerDialog } = useDeleteCustomerDialog()

  const { isCustomerReadyForOverduePayment, loading: isPaymentProcessingStatusLoading } =
    useIsCustomerReadyForOverduePayment()

  const [generatePortalUrl] = useGenerateCustomerPortalUrlMutation({
    onCompleted({ generateCustomerPortalUrl }) {
      handleDownloadFile(generateCustomerPortalUrl?.url)
    },
  })

  const { hasActiveWallet, hasOverdueInvoices } = customer || {}

  return [
    {
      type: 'action',
      label: translate('text_641b1b19d6e64300632ca60c'),
      variant: 'inline',
      startIcon: 'outside',
      onClick: async () => {
        await generatePortalUrl({
          variables: { input: { id: customerId } },
        })
      },
    },
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: CUSTOMER_ACTIONS_BUTTON_TEST_ID,
      items: [
        {
          label: translate('text_66b25adfd834ed0104345eb7'),
          hidden: !hasOverdueInvoices,
          disabled: isPaymentProcessingStatusLoading || !isCustomerReadyForOverduePayment,
          dataTest: REQUEST_OVERDUE_PAYMENT_BUTTON_TEST_ID,
          onClick: (closePopper) => {
            navigate(generatePath(CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE, { customerId }))
            closePopper()
          },
        },
        {
          label: translate('text_626162c62f790600f850b70c'),
          hidden: !hasPermissions(['subscriptionsCreate']),
          onClick: (closePopper) => {
            navigate(generatePath(CREATE_SUBSCRIPTION, { customerId }))
            closePopper()
          },
        },
        {
          label: translate('text_6453819268763979024ad083'),
          hidden: !hasPermissions(['invoicesCreate']),
          dataTest: 'create-invoice-action',
          onClick: (closePopper) => {
            navigate(generatePath(CREATE_INVOICE_ROUTE, { customerId }))
            closePopper()
          },
        },
        {
          label: translate('text_628b8dc14c71840130f8d8a1'),
          hidden: !hasPermissions(['couponsAttach']),
          dataTest: 'apply-coupon-action',
          onClick: (closePopper) => {
            addCouponDialogRef.current?.openDialog()
            closePopper()
          },
        },
        {
          label: translate('text_62d175066d2dbf1d50bc93a5'),
          hidden: !hasPermissions(['walletsCreate']),
          disabled: !!hasActiveWallet,
          onClick: (closePopper) => {
            navigate(generatePath(CREATE_WALLET_ROUTE, { customerId }))
            closePopper()
          },
        },
        {
          label: translate('text_626162c62f790600f850b718'),
          hidden: !hasPermissions(['customersUpdate']),
          onClick: (closePopper) => {
            navigate(generatePath(UPDATE_CUSTOMER_ROUTE, { customerId }))
            closePopper()
          },
        },
        {
          label: translate('text_626162c62f790600f850b726'),
          hidden: !hasPermissions(['customersDelete']),
          onClick: (closePopper) => {
            openDeleteCustomerDialog({
              onDeleted: () => navigate(CUSTOMERS_LIST_ROUTE),
              customer: customer ?? undefined,
            })
            closePopper()
          },
        },
      ],
    },
  ]
}
