import _ from 'lodash'

import { CreditNoteItem } from '~/generated/graphql'

const formatCreditNotesItems = (items: CreditNoteItem[] | null | undefined) => {
  return Object.values(
    _.chain(items)
      .groupBy((item) => item?.fee?.subscription?.id)
      .map((item) => Object.values(_.groupBy(item, (element) => element?.fee?.charge?.id)))
      .value(),
  )
}

export default formatCreditNotesItems
