import { gql } from '@apollo/client'

import {
  GetInvoiceCustomSectionsQuery,
  useGetInvoiceCustomSectionsLazyQuery,
  useGetInvoiceCustomSectionsQuery,
} from '~/generated/graphql'

gql`
  query getInvoiceCustomSections {
    invoiceCustomSections {
      collection {
        id
        name
        code
      }
    }
  }
`

export type InvoiceCustomSection = NonNullable<
  GetInvoiceCustomSectionsQuery['invoiceCustomSections']
>['collection'][number]

interface UseInvoiceCustomSectionsReturn {
  loading: boolean
  error: boolean
  data: InvoiceCustomSection[]
}

interface UseInvoiceCustomSectionsLazyReturn {
  getInvoiceCustomSections: ReturnType<typeof useGetInvoiceCustomSectionsLazyQuery>[0]
  loading: boolean
  error: boolean
  data: InvoiceCustomSection[]
}

/**
 * Hook to fetch ORG invoice custom sections automatically on component mount.
 */
export const useInvoiceCustomSections = (): UseInvoiceCustomSectionsReturn => {
  const { data, loading, error } = useGetInvoiceCustomSectionsQuery()

  const sections = data?.invoiceCustomSections?.collection || []

  return {
    loading,
    error: !!error,
    data: sections,
  }
}

/**
 * Hook to fetch ORG invoice custom sections on demand (lazy loading).
 * Returns a function to trigger the query.
 */
export const useInvoiceCustomSectionsLazy = (): UseInvoiceCustomSectionsLazyReturn => {
  const [getInvoiceCustomSections, { data, loading, error }] =
    useGetInvoiceCustomSectionsLazyQuery()

  const sections = data?.invoiceCustomSections?.collection || []

  return {
    getInvoiceCustomSections,
    loading,
    error: !!error,
    data: sections,
  }
}
