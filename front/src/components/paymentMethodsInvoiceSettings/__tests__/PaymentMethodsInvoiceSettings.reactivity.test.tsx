import { useForm, useStore } from '@tanstack/react-form'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID } from '~/components/paymentMethodSelection/EditPaymentMethodDialog'
import {
  INHERITED_BADGE_TEST_ID,
  MANUAL_PAYMENT_METHOD_TEST_ID,
} from '~/components/paymentMethodSelection/PaymentMethodDisplay'
import {
  PM_FIELDS_FALLBACK_RADIO_TEST_ID,
  PM_FIELDS_MANUAL_RADIO_TEST_ID,
} from '~/components/paymentMethodSelection/PaymentMethodFields'
import { EDIT_PAYMENT_METHOD_BUTTON_TEST_ID } from '~/components/paymentMethodSelection/PaymentMethodSelection'
import { Customer, PaymentMethodsDocument } from '~/generated/graphql'
import {
  createMockPaymentMethod,
  createMockPaymentMethodsQueryResponse,
} from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { render } from '~/test-utils'

import { PaymentMethodsInvoiceSettings } from '../PaymentMethodsInvoiceSettings'
import { SettingsComponentProps, ViewTypeEnum } from '../types'

/**
 * Regression guard for the bug where editing the payment method through the
 * dialog did not update the selection displayed underneath it in the
 * subscription form.
 *
 * Root cause: `CreateSubscription` drives `PaymentMethodsInvoiceSettings` with
 * a hand-rolled `form` adapter over a TanStack Form. Reading
 * `form.state.values` directly in JSX yields a NON-reactive snapshot — the
 * component does not re-subscribe to store changes, so dialog edits are not
 * reflected (the first edit can sneak through only because an unrelated
 * `isDirty` subscription happens to flip false→true and force one re-render).
 *
 * These tests use a REAL TanStack form so the reactivity is exercised for
 * real (no mocked store). The customer is given only an `externalId` so that
 * `PaymentMethodsInvoiceSettings` renders just the `PaymentMethodSelection`
 * branch (no `InvoceCustomFooter`).
 */

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
    locale: 'en',
  }),
}))

const EXTERNAL_CUSTOMER_ID = 'customer_ext_123'

const customer = { externalId: EXTERNAL_CUSTOMER_ID } as unknown as Customer

const defaultPaymentMethod = createMockPaymentMethod({
  id: 'pm_001',
  providerMethodId: 'pm_001',
  isDefault: true,
  details: {
    __typename: 'PaymentMethodDetails',
    brand: 'visa',
    last4: '4242',
    type: 'card',
    expirationMonth: '12',
    expirationYear: '2025',
  },
})

const paymentMethodsMocks = [
  {
    request: {
      query: PaymentMethodsDocument,
      variables: { externalCustomerId: EXTERNAL_CUSTOMER_ID, withDeleted: false },
    },
    result: {
      data: createMockPaymentMethodsQueryResponse([defaultPaymentMethod]),
    },
  },
]

type AdapterValues = {
  paymentMethod?: unknown
  invoiceCustomSection?: unknown
}

const useHarnessForm = () =>
  useForm({
    defaultValues: { paymentMethod: undefined, invoiceCustomSection: undefined } as AdapterValues,
  })

/**
 * Mirrors the FIXED wiring in CreateSubscription: reactive store slices read
 * via `useStore`, so dialog edits re-render the displayed selection.
 */
const ReactiveHarness = () => {
  const form = useHarnessForm()
  const paymentMethod = useStore(form.store, (s) => s.values.paymentMethod)
  const invoiceCustomSection = useStore(form.store, (s) => s.values.invoiceCustomSection)

  return (
    <PaymentMethodsInvoiceSettings
      customer={customer}
      viewType={ViewTypeEnum.Subscription}
      form={
        {
          values: { paymentMethod, invoiceCustomSection },
          setFieldValue: form.setFieldValue,
        } as SettingsComponentProps<ViewTypeEnum.Subscription>['form']
      }
    />
  )
}

/**
 * Mirrors the ORIGINAL buggy wiring: a non-reactive `form.state.values`
 * snapshot, plus an unrelated `isDirty` subscription (as the real form had).
 * The `isDirty` flip lets the FIRST edit render, but subsequent edits do not.
 * Used to prove these tests actually catch the regression.
 */
const SnapshotHarness = () => {
  const form = useHarnessForm()

  // Unrelated subscription that existed in the real form — masks the first edit.
  useStore(form.store, (s) => s.isDirty)

  return (
    <PaymentMethodsInvoiceSettings
      customer={customer}
      viewType={ViewTypeEnum.Subscription}
      form={
        {
          values: form.state.values,
          setFieldValue: form.setFieldValue,
        } as SettingsComponentProps<ViewTypeEnum.Subscription>['form']
      }
    />
  )
}

const openDialogAndSelect = async (radioTestId: string) => {
  await userEvent.click(screen.getByTestId(EDIT_PAYMENT_METHOD_BUTTON_TEST_ID))

  await waitFor(() => {
    expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
  })

  const radioInput = screen
    .getByTestId(radioTestId)
    .querySelector('input[type="radio"]') as HTMLElement

  await userEvent.click(radioInput)
  await userEvent.click(screen.getByTestId(EDIT_PM_DIALOG_SAVE_BUTTON_TEST_ID))

  await waitFor(() => {
    expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
  })
}

describe('PaymentMethodsInvoiceSettings — TanStack form reactivity (subscription form wiring)', () => {
  describe('GIVEN reactive store wiring (the fix)', () => {
    describe('WHEN the payment method is changed repeatedly through the dialog', () => {
      it('THEN the displayed selection reflects EVERY change, not just the first', async () => {
        await act(() => render(<ReactiveHarness />, { mocks: paymentMethodsMocks }))

        // Starts inherited from the customer default (visa **** 4242)
        await waitFor(() => {
          expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
        })
        expect(screen.queryByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).not.toBeInTheDocument()

        // 1st change: fallback -> manual
        await openDialogAndSelect(PM_FIELDS_MANUAL_RADIO_TEST_ID)
        await waitFor(() => {
          expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
        })

        // 2nd change: manual -> fallback (this is where the regression manifested)
        await openDialogAndSelect(PM_FIELDS_FALLBACK_RADIO_TEST_ID)
        await waitFor(() => {
          expect(screen.queryByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).not.toBeInTheDocument()
          expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the original non-reactive snapshot wiring (the regression)', () => {
    describe('WHEN the payment method is changed twice through the dialog', () => {
      it('THEN the first change shows but the second is dropped — confirming the bug shape', async () => {
        await act(() => render(<SnapshotHarness />, { mocks: paymentMethodsMocks }))

        await waitFor(() => {
          expect(screen.getByTestId(INHERITED_BADGE_TEST_ID)).toBeInTheDocument()
        })

        // 1st change reflects (the isDirty flip forces one re-render)
        await openDialogAndSelect(PM_FIELDS_MANUAL_RADIO_TEST_ID)
        await waitFor(() => {
          expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
        })

        // 2nd change is NOT reflected — the display stays stale on "manual"
        await openDialogAndSelect(PM_FIELDS_FALLBACK_RADIO_TEST_ID)
        expect(screen.getByTestId(MANUAL_PAYMENT_METHOD_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
