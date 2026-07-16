import { gql, useApolloClient } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import {
  DeleteBillableMetricDialogFragment,
  GetBillableMetricToDeleteDocument,
  GetBillableMetricToDeleteQuery,
  useDeleteBillableMetricMutation,
} from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteBillableMetricDialog on BillableMetric {
    id
    name
    hasDraftInvoices
    hasActiveSubscriptions
  }

  query getBillableMetricToDelete($id: ID!) {
    billableMetric(id: $id) {
      ...DeleteBillableMetricDialog
    }
  }

  mutation deleteBillableMetric($input: DestroyBillableMetricInput!) {
    destroyBillableMetric(input: $input) {
      id
    }
  }
`

type DeleteBillableMetricDialogProps = {
  billableMetricId: string
  callback?: () => void
}

const buildDescription = (
  translate: TranslateFunc,
  billableMetric: DeleteBillableMetricDialogFragment | null | undefined,
) => {
  const { hasDraftInvoices, hasActiveSubscriptions } = billableMetric || {}

  if (!hasDraftInvoices && !hasActiveSubscriptions) {
    return translate('text_6256f824b6368e01153caa49')
  }

  const usedObjects =
    !!hasDraftInvoices && !!hasActiveSubscriptions
      ? {
          usedObject1: translate('text_63c842ee2cd5dfeb173c2726'),
          usedObject2: translate('text_63c8431193e8aca80f14cced'),
        }
      : {
          usedObject1: !!hasActiveSubscriptions
            ? translate('text_63c842ee2cd5dfeb173c2726')
            : translate('text_63c8431193e8aca80f14cced'),
        }

  return translate(
    'text_63c842d84a91637c3acf0395',
    usedObjects,
    !!hasDraftInvoices && !!hasActiveSubscriptions ? 2 : 0,
  )
}

export const useDeleteBillableMetricDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()
  const client = useApolloClient()

  const [deleteBillableMetric] = useDeleteBillableMetricMutation({
    refetchQueries: ['billableMetrics'],
  })

  const openDeleteBillableMetricDialog = async ({
    billableMetricId,
    callback,
  }: DeleteBillableMetricDialogProps) => {
    const { data } = await client.query<GetBillableMetricToDeleteQuery>({
      query: GetBillableMetricToDeleteDocument,
      variables: { id: billableMetricId },
    })

    const billableMetric = data?.billableMetric
    const { id = '', name = '' } = billableMetric || {}

    centralizedDialog.open({
      title: translate('text_6256f824b6368e01153caa47', {
        billableMetricName: name,
      }),
      description: buildDescription(translate, billableMetric),
      colorVariant: 'danger',
      actionText: translate('text_6256f824b6368e01153caa4d'),
      onAction: async () => {
        const result = await deleteBillableMetric({
          variables: { input: { id } },
        })

        if (result.data?.destroyBillableMetric) {
          addToast({
            message: translate('text_6256f9f1184d3301290c7299'),
            severity: 'success',
          })

          callback?.()
        }
      },
    })
  }

  return { openDeleteBillableMetricDialog }
}
