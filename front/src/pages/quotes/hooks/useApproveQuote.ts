import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { APPROVE_QUOTE_ROUTE, useNavigate } from '~/core/router'
import { useApproveQuoteVersionMutation } from '~/generated/graphql'

gql`
  mutation approveQuoteVersion($input: ApproveQuoteVersionInput!) {
    approveQuoteVersion(input: $input) {
      id
      status
    }
  }
`

export const useApproveQuote = () => {
  const navigate = useNavigate()

  const goToApproveQuote = (quoteId: string, versionId: string) => {
    navigate(generatePath(APPROVE_QUOTE_ROUTE, { quoteId, versionId }))
  }

  const [approveQuote] = useApproveQuoteVersionMutation({
    refetchQueries: ['getQuotes'],
  })

  return { goToApproveQuote, approveQuote }
}
