import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useFormik } from 'formik'
import { createRef } from 'react'
import { object, string } from 'yup'

import {
  EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_ADJUSTMENT_COMBOBOX_TEST_CLASSNAME,
  EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_ANCHOR_COMBOBOX_TEST_CLASSNAME,
  EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_CLOSE_BUTTON_TEST_ID,
  EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_SUBMIT_BUTTON_TEST_ID,
  EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_TEST_ID,
  EditInvoiceIssuingDatePolicyDialogContentBase,
  EditInvoiceIssuingDatePolicyDialogContentRef,
} from '~/components/invoiceIssuingDatePolicy/EditInvoiceIssuingDatePolicyDialogContentBase'
import { MUI_INPUT_BASE_ROOT_CLASSNAME } from '~/core/constants/form'
import { ALL_ADJUSTMENT_VALUES, ALL_ANCHOR_VALUES } from '~/core/constants/issuingDatePolicy'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useIssuingDatePolicy } from '~/hooks/useIssuingDatePolicy'
import { render } from '~/test-utils'

// Mock @tanstack/react-virtual to disable virtualization in tests
// Virtualized lists don't work in jsdom because viewport calculations fail in tests
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getVirtualItems: () => Array.from({ length: count }, (_, index) => ({ key: index, index })),
    getTotalSize: () => count * 56,
    scrollToIndex: () => {},
    measureElement: () => {},
  }),
}))
jest.mock('~/hooks/core/useInternationalization')
jest.mock('~/hooks/useIssuingDatePolicy')

type FormValues = {
  subscriptionInvoiceIssuingDateAnchor: string
  subscriptionInvoiceIssuingDateAdjustment: string
}

async function prepare() {
  const onSubmitMock = jest.fn()
  const dialogRef = createRef<EditInvoiceIssuingDatePolicyDialogContentRef>()

  const TestComponent = (): JSX.Element => {
    const formikProps = useFormik<FormValues>({
      initialValues: {
        subscriptionInvoiceIssuingDateAnchor: '',
        subscriptionInvoiceIssuingDateAdjustment: '',
      },
      validationSchema: object().shape({
        subscriptionInvoiceIssuingDateAnchor: string().required(''),
        subscriptionInvoiceIssuingDateAdjustment: string().required(''),
      }),
      validateOnMount: true,
      onSubmit: onSubmitMock,
    })

    return (
      <EditInvoiceIssuingDatePolicyDialogContentBase
        ref={dialogRef}
        formikProps={formikProps}
        descriptionCopyAsHtml="<p>Description HTML</p>"
        expectedIssuingDateCopy="Expected date: 2025-01-31"
      />
    )
  }

  await act(() => {
    render(<TestComponent />)
  })

  // Open the dialog
  await act(() => {
    dialogRef.current?.openDialog()
  })

  // Wait for dialog to be fully rendered
  await waitFor(() => {
    expect(
      screen.getByTestId(EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_SUBMIT_BUTTON_TEST_ID),
    ).toBeInTheDocument()
  })

  return { onSubmitMock }
}

describe('EditInvoiceIssuingDatePolicyDialogContentBase', () => {
  const translateMock = jest.fn((key: string) => key)
  const useInternationalizationMock = useInternationalization as jest.MockedFunction<
    typeof useInternationalization
  >
  const useIssuingDatePolicyMock = useIssuingDatePolicy as jest.MockedFunction<
    typeof useIssuingDatePolicy
  >

  beforeEach(() => {
    translateMock.mockClear()
    translateMock.mockImplementation((key: string) => key)
    useInternationalizationMock.mockReturnValue({
      translate: translateMock,
      locale: 'en',
      updateLocale: jest.fn(),
    })

    useIssuingDatePolicyMock.mockReturnValue({
      anchorComboboxData: [
        {
          label: 'Current period end',
          value: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        },
        {
          label: 'Next period start',
          value: ALL_ANCHOR_VALUES.NextPeriodStart,
        },
      ],
      adjustmentComboboxData: [
        {
          label: 'Keep anchor',
          value: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        },
        {
          label: 'Align with finalization date',
          value: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        },
      ],
      getIssuingDateInfoForAlert: jest.fn().mockReturnValue({
        descriptionCopyAsHtml: '<p>Description HTML</p>',
        expectedIssuingDateCopy: 'Expected date: 2025-01-31',
      }),
    })
  })

  afterEach(cleanup)

  it('calls resetForm when close button is pressed', async () => {
    await prepare()

    const closeButton = screen.getByTestId(
      EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_CLOSE_BUTTON_TEST_ID,
    )

    expect(closeButton).toBeInTheDocument()

    await userEvent.click(closeButton)

    // Dialog should close (the button click should trigger closeDialog)
    await waitFor(() => {
      expect(
        screen.queryByTestId(EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_CLOSE_BUTTON_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })

  it('disables submit initially, enables after selecting values, then submits', async () => {
    const { onSubmitMock } = await prepare()

    const submitButton = screen.getByTestId(
      EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_SUBMIT_BUTTON_TEST_ID,
    )

    // Step 1: Submit should be disabled when modal opens
    expect(submitButton).toBeDisabled()

    // Step 2: Select value in first combobox (anchor)
    const anchorInput = screen
      .queryByTestId(EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_TEST_ID)
      ?.querySelector(
        `.${EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_ANCHOR_COMBOBOX_TEST_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
      ) as HTMLElement

    await userEvent.click(anchorInput)

    const anchorOptionWrapper = await screen.findByTestId(
      'combobox-item-Current period end',
      {},
      { timeout: 2000 },
    )
    const anchorOption = anchorOptionWrapper.querySelector('.MuiAutocomplete-option')

    await userEvent.click(anchorOption as HTMLElement)

    // Submit should still be disabled (only one field filled, second is still invalid)
    await waitFor(() => {
      expect(submitButton).toBeDisabled()
    })

    // Step 3: Select value in second combobox (adjustment)
    const adjustmentInput = screen
      .queryByTestId(EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_TEST_ID)
      ?.querySelector(
        `.${EDIT_INVOICE_ISSUING_DATE_POLICY_DIALOG_ADJUSTMENT_COMBOBOX_TEST_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
      ) as HTMLElement

    await userEvent.click(adjustmentInput)

    const adjustmentOptionWrapper = await screen.findByTestId('combobox-item-Keep anchor')
    const adjustmentOption = adjustmentOptionWrapper.querySelector('.MuiAutocomplete-option')

    await userEvent.click(adjustmentOption as HTMLElement)

    // Submit should now be enabled (both fields filled and valid)
    await waitFor(() => expect(submitButton).not.toBeDisabled(), { timeout: 3000 })

    // Step 4: Click submit and check form method is called
    await userEvent.click(submitButton)

    await waitFor(() => expect(onSubmitMock).toHaveBeenCalledTimes(1))
  })
})
