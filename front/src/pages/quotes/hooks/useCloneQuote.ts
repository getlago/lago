import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { addToast } from '~/core/apolloClient'
import { EDIT_QUOTE_ROUTE, useNavigate } from '~/core/router'
import { useCloneQuoteVersionMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  mutation cloneQuoteVersion($input: CloneQuoteVersionInput!) {
    cloneQuoteVersion(input: $input) {
      id
      quote {
        id
      }
    }
  }
`

export const useCloneQuote = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const dialog = useCentralizedDialog()

  const [cloneQuoteVersionMutation] = useCloneQuoteVersionMutation({
    refetchQueries: ['getQuotes', 'getQuote'],
  })

  const cloneQuoteVersion = async (versionId: string) => {
    const result = await cloneQuoteVersionMutation({
      variables: { input: { id: versionId } },
    })

    return result.data?.cloneQuoteVersion ?? null
  }

  const openCloneDialog = (versionId: string, quoteNumberAndVersion: string) => {
    dialog.open({
      title: translate('text_1776414006125wn9p70fx8qg', { quoteNumberAndVersion }),
      description: translate('text_1776414006125pkw558zpwid'),
      actionText: translate('text_1776417548746htq2me6cmnw'),
      onAction: async () => {
        const clonedQuote = await cloneQuoteVersion(versionId)

        if (clonedQuote) {
          addToast({
            severity: 'success',
            message: translate('text_1776414006125wn9p70fx8qg', { quoteNumberAndVersion }),
          })

          navigate(
            generatePath(EDIT_QUOTE_ROUTE, {
              quoteId: clonedQuote.quote.id,
              versionId: clonedQuote.id,
            }),
          )
        }

        return { reason: 'success' } as const
      },
    })
  }

  return { openCloneDialog, cloneQuoteVersion }
}
