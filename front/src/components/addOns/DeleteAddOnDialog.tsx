import { gql } from '@apollo/client'

import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { DeleteAddOnFragment, useDeleteAddOnMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment DeleteAddOn on AddOn {
    id
    name
  }

  mutation deleteAddOn($input: DestroyAddOnInput!) {
    destroyAddOn(input: $input) {
      id
    }
  }
`

type DeleteAddOnDialogData = {
  addOn: DeleteAddOnFragment
  callback?: () => void
}

export const useDeleteAddOnDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [deleteAddOn] = useDeleteAddOnMutation({
    refetchQueries: ['addOns'],
  })

  const openDeleteAddOnDialog = ({ addOn, callback }: DeleteAddOnDialogData) => {
    centralizedDialog.open({
      title: translate('text_629728388c4d2300e2d380ad', { addOnName: addOn.name }),
      description: <Typography html={translate('text_629728388c4d2300e2d380c5')} />,
      colorVariant: 'danger',
      actionText: translate('text_629728388c4d2300e2d380f5'),
      onAction: async () => {
        const result = await deleteAddOn({
          variables: { input: { id: addOn.id } },
        })

        if (result.data?.destroyAddOn) {
          addToast({
            message: translate('text_629728388c4d2300e2d3815f'),
            severity: 'success',
          })

          callback?.()
        }
      },
    })
  }

  return { openDeleteAddOnDialog }
}
