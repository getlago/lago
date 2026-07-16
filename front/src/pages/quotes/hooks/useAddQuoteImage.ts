import { gql } from '@apollo/client'

import { type AddQuoteImageInput, useAddQuoteImageMutation } from '~/generated/graphql'

gql`
  mutation addQuoteImage($input: AddQuoteImageInput!) {
    addQuoteImage(input: $input) {
      id
      url
    }
  }
`

export const useAddQuoteImage = () => {
  const [addQuoteImageMutation, { loading: isUploadingImage }] = useAddQuoteImageMutation()

  const addQuoteImage = async (input: AddQuoteImageInput): Promise<{ id: string; url: string }> => {
    const result = await addQuoteImageMutation({ variables: { input } })

    if (!result.data?.addQuoteImage) {
      throw new Error('Quote image upload failed')
    }

    return result.data.addQuoteImage
  }

  return { addQuoteImage, isUploadingImage }
}
