import { renderHook } from '@testing-library/react'

import { PaymentMethodTypeEnum, useUpdateSubscriptionMutation } from '~/generated/graphql'

import { useUpdateSubscriptionSettings } from '../useUpdateSubscriptionSettings'

jest.mock('~/generated/graphql', () => ({
  LagoApiError: { UnprocessableEntity: 'unprocessable_entity' },
  PaymentMethodTypeEnum: { Provider: 'provider', Manual: 'manual' },
  useUpdateSubscriptionMutation: jest.fn(),
}))

jest.mock('~/core/apolloClient', () => ({ addToast: jest.fn() }))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const mockUpdate = jest.fn().mockResolvedValue({ data: { updateSubscription: { id: 'sub_1' } } })

describe('useUpdateSubscriptionSettings', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    ;(useUpdateSubscriptionMutation as jest.Mock).mockReturnValue([mockUpdate, {}])
  })

  it('savePayment sends the payment method on the subscription input', async () => {
    const { result } = renderHook(() => useUpdateSubscriptionSettings('sub_1'))

    await result.current.savePayment({
      paymentMethod: { paymentMethodId: 'pm_1', paymentMethodType: PaymentMethodTypeEnum.Provider },
    })

    expect(mockUpdate).toHaveBeenCalledWith({
      variables: {
        input: {
          id: 'sub_1',
          paymentMethod: {
            paymentMethodId: 'pm_1',
            paymentMethodType: PaymentMethodTypeEnum.Provider,
          },
        },
      },
    })
  })

  it('savePayment sends an undefined payment method when none is selected', async () => {
    const { result } = renderHook(() => useUpdateSubscriptionSettings('sub_1'))

    await result.current.savePayment({ paymentMethod: undefined })

    expect(mockUpdate).toHaveBeenCalledWith({
      variables: { input: { id: 'sub_1', paymentMethod: undefined } },
    })
  })

  it('saveInvoicing sends consolidation + custom-section reference', async () => {
    const { result } = renderHook(() => useUpdateSubscriptionSettings('sub_1'))

    await result.current.saveInvoicing({
      consolidateInvoice: false,
      invoiceCustomSection: {
        invoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
        skipInvoiceCustomSections: false,
      },
    })

    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          input: expect.objectContaining({ id: 'sub_1', consolidateInvoice: false }),
        }),
      }),
    )
  })

  it('rejects when the mutation resolves without a subscription (so the drawer stays open)', async () => {
    mockUpdate.mockResolvedValueOnce({ data: { updateSubscription: null } })

    const { result } = renderHook(() => useUpdateSubscriptionSettings('sub_1'))

    await expect(result.current.savePayment({ paymentMethod: undefined })).rejects.toThrow()
  })
})
