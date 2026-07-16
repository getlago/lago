import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'

import { AddQuoteImageDocument } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useAddQuoteImage } from '../useAddQuoteImage'

const mocks = [
  {
    request: {
      query: AddQuoteImageDocument,
      variables: { input: { id: 'quote-1', image: 'data:image/png;base64,AAA' } },
    },
    result: { data: { addQuoteImage: { id: 'blob-1', url: 'https://signed/blob-1' } } },
  },
]

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders mocks={mocks}>{children}</AllTheProviders>
)

describe('useAddQuoteImage', () => {
  describe('GIVEN a matching mutation mock', () => {
    describe('WHEN addQuoteImage is called', () => {
      it('THEN returns the created blob id and url', async () => {
        const { result } = renderHook(() => useAddQuoteImage(), { wrapper })

        let out: { id: string; url: string } | undefined

        await act(async () => {
          out = await result.current.addQuoteImage({
            id: 'quote-1',
            image: 'data:image/png;base64,AAA',
          })
        })

        expect(out).toEqual({ id: 'blob-1', url: 'https://signed/blob-1' })
      })
    })
  })
})
