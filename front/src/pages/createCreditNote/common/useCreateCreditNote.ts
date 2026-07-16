import { ApolloError, gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { CreditNoteForm, FeesPerInvoice, FromFee } from '~/components/creditNote/types'
import {
  buildCreditNoteFees,
  hasCreditableOrRefundableAmount as hasCreditableOrRefundableAmountUtil,
  isCreditNoteCreationDisabled,
} from '~/components/creditNote/utils'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import {
  composeChargeFilterDisplayName,
  composeGroupedByDisplayName,
  composeMultipleValuesWithSepator,
} from '~/core/formats/formatInvoiceItemsMap'
import {
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  ERROR_404_ROUTE,
  useNavigate,
} from '~/core/router'
import { serializeCreditNoteInput } from '~/core/serializers'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreateCreditNoteInvoiceFragmentDoc,
  CreditNoteTableItemFragmentDoc,
  CurrencyEnum,
  Fee,
  FeeTypesEnum,
  GetInvoiceCreditNotesDocument,
  GetInvoiceCreditNotesQuery,
  GetInvoiceCreditNotesQueryVariables,
  InvoiceCreateCreditNoteFragment,
  InvoiceTypeEnum,
  LagoApiError,
  useCreateCreditNoteMutation,
  useGetInvoiceCreateCreditNoteQuery,
} from '~/generated/graphql'

gql`
  fragment InvoiceFee on Fee {
    id
    amountCurrency
    feeType
    invoiceName
    invoiceDisplayName
    groupedBy
    succeededAt
    appliedTaxes {
      id
      taxName
      taxRate
    }
    creditableAmountCents
    offsettableAmountCents
    trueUpFee {
      id
    }
    charge {
      id
      billableMetric {
        id
        name
      }
    }
    chargeFilter {
      id
      invoiceDisplayName
      values
    }
  }

  fragment CreateCreditNoteInvoice on Invoice {
    id
    currency
    number
    status
    paymentStatus
    creditableAmountCents
    refundableAmountCents
    offsettableAmountCents
    subTotalIncludingTaxesAmountCents
    availableToCreditAmountCents
    totalPaidAmountCents
    totalAmountCents
    totalDueAmountCents
    paymentDisputeLostAt
    invoiceType
    ...InvoiceForCreditNoteFormCalculation
    ...InvoiceForCreditNoteFormCalculation
  }

  fragment InvoiceCreateCreditNote on Invoice {
    id
    refundableAmountCents
    creditableAmountCents
    offsettableAmountCents
    invoiceType
    fees {
      id
      amountCurrency
      itemCode
      itemName
      invoiceName
      invoiceDisplayName
      creditableAmountCents
      offsettableAmountCents
      succeededAt
      appliedTaxes {
        id
        taxName
        taxRate
      }
      trueUpFee {
        id
      }
    }
    invoiceSubscriptions {
      subscription {
        id
        name
        plan {
          id
          name
          invoiceDisplayName
        }
      }
      fees {
        ...InvoiceFee
      }
    }
    ...CreateCreditNoteInvoice
  }

  query getInvoiceCreateCreditNote($id: ID!) {
    invoice(id: $id) {
      ...InvoiceCreateCreditNote
    }
  }

  mutation createCreditNote($input: CreateCreditNoteInput!) {
    createCreditNote(input: $input) {
      id
      ...CreditNoteTableItem
    }
  }

  ${CreateCreditNoteInvoiceFragmentDoc}
  ${CreditNoteTableItemFragmentDoc}
`

type UseCreateCreditNoteReturn = {
  loading: boolean
  invoice?: InvoiceCreateCreditNoteFragment
  feesPerInvoice?: FeesPerInvoice
  feeForAddOn?: FromFee[]
  feeForCredit?: FromFee[]
  hasCreditableOrRefundableAmount: boolean
  onCreate: (
    value: CreditNoteForm,
  ) => Promise<{ data?: { createCreditNote?: { id?: string } }; errors?: ApolloError }>
}

export const useCreateCreditNote: () => UseCreateCreditNoteReturn = () => {
  const { invoiceId, customerId } = useParams()
  const navigate = useNavigate()
  const { data, error, loading } = useGetInvoiceCreateCreditNoteQuery({
    fetchPolicy: 'network-only',
    context: { silentError: LagoApiError.NotFound },
    variables: {
      id: invoiceId as string,
    },
    skip: !invoiceId,
  })
  const [create] = useCreateCreditNoteMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    // Updates the invoice fields (creditableAmountCents, refundableAmountCents) in background.
    // We can't include these fields directly in the mutation response because it would update the invoice
    // in cache before navigation, causing a 404 redirect on back button
    refetchQueries: ['getInvoiceCreditNotes'],
    // Apollo only normalizes single entities, not lists. When creating a new credit note,
    // Apollo caches the entity but doesn't know which lists should include it.
    // We manually add the new credit note reference to the cached list for immediate UI update.
    update(cache, { data: mutationData }) {
      if (!mutationData?.createCreditNote) return

      const newCreditNote = mutationData.createCreditNote

      cache.updateQuery<GetInvoiceCreditNotesQuery, GetInvoiceCreditNotesQueryVariables>(
        {
          query: GetInvoiceCreditNotesDocument,
          variables: { invoiceId: invoiceId as string, limit: 20 },
        },
        (cachedData) => {
          if (!cachedData?.invoiceCreditNotes) return cachedData

          return {
            ...cachedData,
            invoiceCreditNotes: {
              ...cachedData.invoiceCreditNotes,
              metadata: {
                ...cachedData.invoiceCreditNotes.metadata,
                totalCount: (cachedData.invoiceCreditNotes.metadata.totalCount || 0) + 1,
              },
              collection: [newCreditNote, ...cachedData.invoiceCreditNotes.collection],
            },
          }
        },
      )
    },
    onCompleted({ createCreditNote }) {
      if (createCreditNote) {
        addToast({
          severity: 'success',
          translateKey: 'text_63763e61409e0d55b268a590',
        })

        navigate(
          generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
            customerId: customerId as string,
            invoiceId: invoiceId as string,
            creditNoteId: createCreditNote.id,
          }),
        )
      }
    },
    onError() {
      addToast({
        severity: 'danger',
        translateKey: 'text_622f7a3dc32ce100c46a5154',
      })
    },
  })

  if (
    !invoiceId ||
    hasDefinedGQLError('NotFound', error, 'invoice') ||
    isCreditNoteCreationDisabled(data?.invoice)
  ) {
    navigate(ERROR_404_ROUTE)
  }

  const hasCreditableOrRefundableAmount = hasCreditableOrRefundableAmountUtil(data?.invoice)

  const feeForCredit = useMemo(() => {
    if (data?.invoice?.invoiceType === InvoiceTypeEnum.Credit) {
      const result = buildCreditNoteFees(data?.invoice?.fees, hasCreditableOrRefundableAmount)

      return result.length > 0 ? result : undefined
    }

    return undefined
  }, [data?.invoice, hasCreditableOrRefundableAmount])

  const feeForAddOn = useMemo(() => {
    if (
      data?.invoice?.invoiceType === InvoiceTypeEnum.AddOn ||
      data?.invoice?.invoiceType === InvoiceTypeEnum.OneOff
    ) {
      const result = buildCreditNoteFees(data?.invoice?.fees, hasCreditableOrRefundableAmount)

      return result.length > 0 ? result : undefined
    }

    return undefined
  }, [data?.invoice, hasCreditableOrRefundableAmount])

  const feesPerInvoice = useMemo(() => {
    return data?.invoice?.invoiceSubscriptions?.reduce<FeesPerInvoice>(
      (subAcc, invoiceSubscription) => {
        const subscriptionName: string =
          invoiceSubscription?.subscription?.name ||
          invoiceSubscription?.subscription?.plan?.invoiceDisplayName ||
          invoiceSubscription?.subscription?.plan?.name

        const trueUpFeeIds = invoiceSubscription?.fees?.reduce<string[]>((acc, fee) => {
          if (fee?.trueUpFee?.id) {
            acc.push(fee?.trueUpFee?.id)
          }
          return acc
        }, [])

        // We need to reorder fees to have true up fees after their "parent" related charge
        const reorderFees = (unorderedData: Fee[]) => {
          if (!unorderedData.length || trueUpFeeIds?.length === 0) return unorderedData

          const feesWithoutTrueUpOnes = invoiceSubscription?.fees?.filter(
            (fee) => !trueUpFeeIds?.includes(fee?.id),
          )
          const newFees = []

          for (const currentFee of feesWithoutTrueUpOnes || []) {
            if (currentFee?.trueUpFee?.id) {
              const relatedTrueUpFee = unorderedData.find(
                (fee) => fee.id === currentFee.trueUpFee?.id,
              )

              newFees.push(currentFee, relatedTrueUpFee)
            } else {
              newFees.push(currentFee)
            }
          }

          return newFees
        }

        const orderedData = [...reorderFees(invoiceSubscription?.fees as Fee[])].sort((a, b) => {
          if (a?.feeType === FeeTypesEnum.Commitment && b?.feeType !== FeeTypesEnum.Commitment) {
            return 1
          } else if (
            a?.feeType !== FeeTypesEnum.Commitment &&
            b?.feeType === FeeTypesEnum.Commitment
          ) {
            return -1
          }
          return 0
        })

        const subscriptionFees = orderedData.reduce<FromFee[]>((acc, fee) => {
          if (!fee) {
            return acc
          }

          const amountCents = hasCreditableOrRefundableAmount
            ? fee.creditableAmountCents
            : fee.offsettableAmountCents

          if (Number(amountCents) <= 0) {
            return acc
          }

          const composableName =
            fee.invoiceDisplayName ||
            (fee.feeType === FeeTypesEnum.Commitment
              ? 'Minimum commitment - True up'
              : composeMultipleValuesWithSepator([
                  fee.invoiceName || subscriptionName,
                  composeChargeFilterDisplayName(fee.chargeFilter),
                  composeGroupedByDisplayName(fee.groupedBy),
                ]))

          acc.push({
            id: fee.id,
            checked: true,
            value: deserializeAmount(amountCents, fee.amountCurrency),
            name: composableName,
            isTrueUpFee: trueUpFeeIds?.includes(fee.id),
            maxAmount: Number(amountCents),
            appliedTaxes: fee.appliedTaxes || [],
            succeededAt: fee.succeededAt,
            isReadOnly: !hasCreditableOrRefundableAmount,
          })

          return acc
        }, [])

        return subscriptionFees.length > 0
          ? {
              ...subAcc,
              [invoiceSubscription?.subscription?.id]: {
                subscriptionName,
                fees: subscriptionFees,
              },
            }
          : subAcc
      },
      {},
    )
  }, [data?.invoice, hasCreditableOrRefundableAmount])

  return {
    loading,
    invoice: data?.invoice || undefined,
    feesPerInvoice,
    feeForAddOn,
    feeForCredit,
    hasCreditableOrRefundableAmount,
    onCreate: async (values) => {
      const answer = await create({
        variables: {
          input: serializeCreditNoteInput(
            invoiceId as string,
            values,
            data?.invoice?.currency || CurrencyEnum.Usd,
          ),
        },
      })

      return answer as Promise<{
        data?: { createCreditNote?: { id?: string } }
        errors?: ApolloError
      }>
    },
  }
}
