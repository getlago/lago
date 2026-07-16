import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { CUSTOMER_DETAILS_TAB_ROUTE, useNavigate } from '~/core/router'
import {
  CustomerDetailsFragment,
  CustomerDetailsFragmentDoc,
  useTerminateCustomerWalletMutation,
  WalletAccordionFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation terminateCustomerWallet($input: TerminateCustomerWalletInput!) {
    terminateCustomerWallet(input: $input) {
      id
      status
      ...WalletAccordion
      customer {
        id
        hasActiveWallet
      }
    }
  }

  ${WalletAccordionFragmentDoc}
`

type TerminateCustomerWalletDialogProps = {
  walletId?: string
}

export const useTerminateCustomerWalletDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { customerId } = useParams()

  const [terminateWallet] = useTerminateCustomerWalletMutation({
    update(cache, { data }) {
      if (!data?.terminateCustomerWallet) return

      const cacheId = `Customer:${data.terminateCustomerWallet.customer?.id}`

      const previousData: CustomerDetailsFragment | null = cache.readFragment({
        id: cacheId,
        fragment: CustomerDetailsFragmentDoc,
        fragmentName: 'CustomerDetails',
      })

      cache.writeFragment({
        id: cacheId,
        fragment: CustomerDetailsFragmentDoc,
        fragmentName: 'CustomerDetails',
        data: {
          ...previousData,
          hasActiveWallet: data.terminateCustomerWallet.customer?.hasActiveWallet,
        },
      })
    },
    refetchQueries: ['getCustomerWalletList'],
  })

  const openTerminateCustomerWalletDialog = (props?: TerminateCustomerWalletDialogProps) => {
    if (!props) {
      return
    }

    centralizedDialog.open({
      title: translate('text_62d9430e8b9fe36851cddd0b'),
      description: translate('text_62d9430e8b9fe36851cddd0f'),
      colorVariant: 'danger',
      actionText: translate('text_62d9430e8b9fe36851cddd17'),
      onAction: async () => {
        const result = await terminateWallet({
          variables: { input: { id: props.walletId as string } },
        })

        if (result.data?.terminateCustomerWallet) {
          addToast({
            severity: 'success',
            translateKey: 'text_62e257c032ae895bbfead62e',
          })

          navigate(
            generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
              customerId: customerId as string,
              tab: CustomerDetailsTabsOptions.wallet,
            }),
          )
        }
      },
    })
  }

  return { openTerminateCustomerWalletDialog }
}
