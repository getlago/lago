import { gql } from '@apollo/client'

import { InvoiceCustomSectionBasic } from '~/components/invoceCustomFooter/types'
import {
  EditCustomerInvoiceCustomSectionFragment,
  useGetCustomerInvoiceCustomSectionsQuery,
} from '~/generated/graphql'

gql`
  fragment EditCustomerInvoiceCustomSection on Customer {
    id
    externalId
    configurableInvoiceCustomSections {
      id
      name
    }
    hasOverwrittenInvoiceCustomSectionsSelection
    skipInvoiceCustomSections
  }

  query getCustomerInvoiceCustomSections($customerId: ID!) {
    customer(id: $customerId) {
      id
      ...EditCustomerInvoiceCustomSection
    }
  }
`

interface CustomerInvoiceCustomSectionsData {
  configurableInvoiceCustomSections: InvoiceCustomSectionBasic[]
  hasOverwrittenInvoiceCustomSectionsSelection: boolean
  skipInvoiceCustomSections: boolean
}

interface UseCustomerInvoiceCustomSectionsReturn {
  loading: boolean
  error: boolean
  data: CustomerInvoiceCustomSectionsData | null
  customer: EditCustomerInvoiceCustomSectionFragment | null
}

/**
 * Hook to fetch customer invoice custom sections settings.
 */
export const useCustomerInvoiceCustomSections = (
  customerId: string | undefined,
): UseCustomerInvoiceCustomSectionsReturn => {
  const { data, loading, error } = useGetCustomerInvoiceCustomSectionsQuery({
    variables: { customerId: customerId as string },
    skip: !customerId,
  })

  const customer = data?.customer ?? null

  if (!customer) {
    return {
      loading,
      error: !!error,
      data: null,
      customer: null,
    }
  }

  const processedData: CustomerInvoiceCustomSectionsData = {
    configurableInvoiceCustomSections:
      customer.configurableInvoiceCustomSections?.map((s) => ({
        id: s.id,
        name: s.name ?? '',
      })) ?? [],
    hasOverwrittenInvoiceCustomSectionsSelection:
      customer.hasOverwrittenInvoiceCustomSectionsSelection ?? false,
    skipInvoiceCustomSections: customer.skipInvoiceCustomSections ?? false,
  }

  return {
    loading,
    error: !!error,
    data: processedData,
    customer,
  }
}
