import { gql } from '@apollo/client'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, useVoidCreditNoteMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CreditNoteForVoidCreditNoteDialog on CreditNote {
    id
    totalAmountCents
    currency
  }

  mutation voidCreditNote($input: VoidCreditNoteInput!) {
    voidCreditNote(input: $input) {
      id
    }
  }
`

type CreditNoteForVoid = {
  id: string
  totalAmountCents: number
  currency: CurrencyEnum
}

export const useVoidCreditNoteDialog = () => {
  const centralizedDialog = useCentralizedDialog()
  const { translate } = useInternationalization()

  const [voidCreditNote] = useVoidCreditNoteMutation({
    onCompleted({ voidCreditNote: voidedCreditNote }) {
      if (!!voidedCreditNote) {
        addToast({
          severity: 'success',
          translateKey: 'text_63720bd734e1344aea75b85d',
        })
      }
    },
  })

  const openVoidCreditNoteDialog = (creditNote: CreditNoteForVoid) => {
    centralizedDialog.open({
      title: translate('text_63720bd734e1344aea75b7db'),
      description: translate('text_63720bd734e1344aea75b7e1', {
        amount: intlFormatNumber(
          deserializeAmount(creditNote.totalAmountCents || 0, creditNote.currency),
          {
            currencyDisplay: 'symbol',
            currency: creditNote.currency,
          },
        ),
      }),
      colorVariant: 'danger',
      actionText: translate('text_63720bd734e1344aea75b7e9'),
      onAction: async () => {
        await voidCreditNote({
          variables: { input: { id: creditNote.id } },
          refetchQueries: ['getCustomer', 'getCreditNote'],
        })
      },
    })
  }

  return { openVoidCreditNoteDialog }
}
