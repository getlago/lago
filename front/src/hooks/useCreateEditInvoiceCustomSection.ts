import { gql } from '@apollo/client'
import { useEffect, useMemo } from 'react'
import { useParams } from 'react-router-dom'

import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { ERROR_404_ROUTE, INVOICE_SETTINGS_ROUTE, useNavigate } from '~/core/router'
import {
  CreateInvoiceCustomSectionInput,
  InvoiceCustomSectionFormFragment,
  LagoApiError,
  useCreateInvoiceCustomSectionMutation,
  useGetSingleInvoiceCustomSectionQuery,
  useUpdateInvoiceCustomSectionMutation,
} from '~/generated/graphql'

gql`
  fragment InvoiceCustomSectionForm on InvoiceCustomSection {
    name
    code
    description
    details
    displayName
  }

  query getSingleInvoiceCustomSection($id: ID!) {
    invoiceCustomSection(id: $id) {
      id
      ...InvoiceCustomSectionForm
    }
  }

  mutation createInvoiceCustomSection($input: CreateInvoiceCustomSectionInput!) {
    createInvoiceCustomSection(input: $input) {
      id
      ...InvoiceCustomSectionForm
    }
  }

  mutation updateInvoiceCustomSection($input: UpdateInvoiceCustomSectionInput!) {
    updateInvoiceCustomSection(input: $input) {
      id
      ...InvoiceCustomSectionForm
    }
  }
`

interface UseCreateEditInvoiceCustomSectionReturn {
  loading: boolean
  errorCode?: string
  isEdition: boolean
  invoiceCustomSection?: InvoiceCustomSectionFormFragment
  onSave: (value: CreateInvoiceCustomSectionInput) => Promise<void>
  onClose: () => void
}

export const useCreateEditInvoiceCustomSection = (): UseCreateEditInvoiceCustomSectionReturn => {
  const navigate = useNavigate()
  const { sectionId } = useParams<string>()

  const { data, loading, error } = useGetSingleInvoiceCustomSectionQuery({
    variables: {
      id: sectionId as string,
    },
    skip: !sectionId,
  })

  const [create, { error: createError }] = useCreateInvoiceCustomSectionMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createInvoiceCustomSection }) {
      if (!!createInvoiceCustomSection) {
        addToast({
          severity: 'success',
          translateKey: 'text_17338418252493b2rz0ks49m',
        })
      }
      navigate(INVOICE_SETTINGS_ROUTE)
    },
  })

  const [update, { error: updateError }] = useUpdateInvoiceCustomSectionMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updateInvoiceCustomSection }) {
      if (!!updateInvoiceCustomSection) {
        addToast({
          severity: 'success',
          translateKey: 'text_1733841825249i5g7vr4gnzo',
        })
      }
      navigate(INVOICE_SETTINGS_ROUTE)
    },
  })

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'invoiceCustomSection')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  const errorCode = useMemo(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      return FORM_ERRORS_ENUM.existingCode
    }

    return undefined
  }, [createError, updateError])

  return useMemo(
    () => ({
      loading,
      errorCode,
      isEdition: !!sectionId,
      invoiceCustomSection: data?.invoiceCustomSection || undefined,
      onClose: () => navigate(INVOICE_SETTINGS_ROUTE),
      onSave: async (values) => {
        !!sectionId
          ? await update({
              variables: {
                input: {
                  ...values,
                  id: sectionId,
                },
              },
            })
          : await create({
              variables: {
                input: {
                  ...values,
                },
              },
            })
      },
    }),
    [sectionId, data?.invoiceCustomSection, errorCode, loading, navigate, create, update],
  )
}
