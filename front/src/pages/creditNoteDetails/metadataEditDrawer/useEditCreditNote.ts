import { gql } from '@apollo/client'

import { useEditCreditNoteMutation } from '~/generated/graphql'

gql`
  mutation EditCreditNote($input: UpdateCreditNoteInput!) {
    updateCreditNote(input: $input) {
      id
    }
  }
`

type UseEditCreditNoteReturn = {
  updateCreditNote: ReturnType<typeof useEditCreditNoteMutation>[0]
  isUpdatingCreditNote: boolean
}

export const useEditCreditNote = (): UseEditCreditNoteReturn => {
  const [updateCreditNote, { loading: isUpdatingCreditNote }] = useEditCreditNoteMutation({
    refetchQueries: ['getCreditNoteForDetails'],
  })

  return {
    updateCreditNote,
    isUpdatingCreditNote,
  }
}
