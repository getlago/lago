/**
 * Integration tests for ChargeFilterDrawerContent using a REAL TanStack Form instance.
 *
 * These tests verify form state management and validation — the exact behaviors
 * that broke in production due to effect ordering and formApi.update() overwriting
 * reset values. They complement the unit tests which mock TanStack Form entirely.
 */
import { revalidateLogic } from '@tanstack/react-form'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ChargeFilterDrawerProvider } from '~/contexts/ChargeFilterDrawerContext'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import { ChargeModelEnum, CurrencyEnum } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import {
  chargeFilterDrawerSchema,
  ChargeFilterFormValues,
  ChargeFilterDrawerContent as OriginalChargeFilterDrawerContent,
} from '../ChargeFilterDrawerContent'

// Cast to strip the strict form generic — we pass a real form instance

const ChargeFilterDrawerContent = OriginalChargeFilterDrawerContent as React.FC<any>

// --- Mocks (UI only — form logic is real) ---

jest.mock('~/components/plans/chargeAccordion/ChargeWrapperSwitch', () => ({
  ChargeWrapperSwitch: () => <div data-test="charge-wrapper-switch" />,
}))

jest.mock('~/components/plans/chargeAccordion/ChargeFilter', () => ({
  ChargeFilter: (props: { filter: { values: string[] } }) => (
    <div data-test="charge-filter">{props.filter.values.join(',')}</div>
  ),
  buildChargeFilterAddFilterButtonId: jest.fn(),
}))

// --- Helpers ---

const defaultFilterValues: ChargeFilterFormValues = {
  chargeModel: ChargeModelEnum.Standard,
  invoiceDisplayName: '',
  properties: getPropertyShape({}),
  values: [],
}

/**
 * Wrapper that creates a real TanStack form and renders ChargeFilterDrawerContent.
 * The `onSubmit` callback captures submitted values.
 * The `initialValues` option resets the form before rendering (simulates openFilterDrawer).
 */
function FilterDrawerHarness({
  chargeModel = ChargeModelEnum.Standard,
  initialValues,
  onSubmit = jest.fn(),
}: {
  chargeModel?: ChargeModelEnum
  initialValues?: ChargeFilterFormValues
  onSubmit?: jest.Mock
}) {
  const form = useAppForm({
    defaultValues: initialValues ?? defaultFilterValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: chargeFilterDrawerSchema },
    onSubmit: ({ value }) => onSubmit(value),
  })

  return (
    <ChargeFilterDrawerProvider
      chargeModel={chargeModel}
      chargeType="usage"
      currency={CurrencyEnum.Usd}
      chargePricingUnitShortName={undefined}
      isEdition={false}
    >
      <ChargeFilterDrawerContent
        form={form}
        billableMetricFilters={[]}
        chargeIndex={0}
        filterIndex={0}
      />
      {/* Visible submit button for testing (in real UI it's in the drawer actions) */}
      <button data-test="submit-btn" onClick={() => form.handleSubmit()}>
        Submit
      </button>
      {/* Display form state for assertion */}
      <form.Subscribe selector={(state) => state.errorMap}>
        {(errorMap) => <div data-test="form-errors">{JSON.stringify(errorMap)}</div>}
      </form.Subscribe>
      <form.Subscribe selector={(state) => state.canSubmit}>
        {(canSubmit) => <div data-test="can-submit">{String(canSubmit)}</div>}
      </form.Subscribe>
    </ChargeFilterDrawerProvider>
  )
}

// --- Tests ---

describe('ChargeFilterDrawerContent (integration)', () => {
  describe('GIVEN a filter with pre-populated standard charge values', () => {
    const savedFilter: ChargeFilterFormValues = {
      chargeModel: ChargeModelEnum.Standard,
      invoiceDisplayName: 'My Standard Filter',
      properties: { ...getPropertyShape({}), amount: '42' },
      values: ['region:us'],
    }

    it('THEN should render the saved invoice display name', () => {
      render(<FilterDrawerHarness initialValues={savedFilter} />)

      const input = document.querySelector('input[name="invoiceDisplayName"]') as HTMLInputElement

      expect(input?.value).toBe('My Standard Filter')
    })

    it('THEN should pass saved filter values to ChargeFilter', () => {
      render(<FilterDrawerHarness initialValues={savedFilter} />)

      expect(screen.getByTestId('charge-filter')).toHaveTextContent('region:us')
    })
  })

  describe('GIVEN a filter with pre-populated graduated charge values', () => {
    const savedGraduatedFilter: ChargeFilterFormValues = {
      chargeModel: ChargeModelEnum.Graduated,
      invoiceDisplayName: 'Graduated Filter',
      properties: {
        ...getPropertyShape({}),
        graduatedRanges: [
          { fromValue: 0, toValue: 10, perUnitAmount: '1', flatAmount: '0' },
          { fromValue: 11, toValue: null, perUnitAmount: '0.5', flatAmount: '0' },
        ],
      },
      values: ['region:eu'],
    }

    it('THEN should render the saved invoice display name', () => {
      render(
        <FilterDrawerHarness
          chargeModel={ChargeModelEnum.Graduated}
          initialValues={savedGraduatedFilter}
        />,
      )

      const input = document.querySelector('input[name="invoiceDisplayName"]') as HTMLInputElement

      expect(input?.value).toBe('Graduated Filter')
    })
  })

  describe('GIVEN an existing standard filter is opened and edited', () => {
    const savedFilter: ChargeFilterFormValues = {
      chargeModel: ChargeModelEnum.Standard,
      invoiceDisplayName: 'Original Name',
      properties: { ...getPropertyShape({}), amount: '42' },
      values: ['region:us'],
    }

    it('THEN canSubmit should remain true after editing a field', async () => {
      render(<FilterDrawerHarness initialValues={savedFilter} />)

      // Initially canSubmit should be true (untouched, no errors)
      expect(screen.getByTestId('can-submit')).toHaveTextContent('true')

      // Edit the invoice display name
      const input = document.querySelector('input[name="invoiceDisplayName"]') as HTMLInputElement

      await act(async () => {
        await userEvent.clear(input)
        await userEvent.type(input, 'Updated Name')
      })

      // canSubmit should still be true after editing
      await waitFor(() => {
        expect(screen.getByTestId('can-submit')).toHaveTextContent('true')
      })
    })

    it('THEN submitting after editing should call onSubmit', async () => {
      const onSubmit = jest.fn()

      render(<FilterDrawerHarness initialValues={savedFilter} onSubmit={onSubmit} />)

      // Edit the invoice display name
      const input = document.querySelector('input[name="invoiceDisplayName"]') as HTMLInputElement

      await act(async () => {
        await userEvent.clear(input)
        await userEvent.type(input, 'Updated Name')
      })

      // Submit the form
      await act(async () => {
        await userEvent.click(screen.getByTestId('submit-btn'))
      })

      await waitFor(() => {
        expect(onSubmit).toHaveBeenCalledWith(
          expect.objectContaining({ invoiceDisplayName: 'Updated Name' }),
        )
      })
    })
  })

  describe('GIVEN a standard charge filter with empty required fields', () => {
    it('THEN submitting should produce validation errors', async () => {
      const onSubmit = jest.fn()

      render(<FilterDrawerHarness onSubmit={onSubmit} />)

      await act(async () => {
        await userEvent.click(screen.getByTestId('submit-btn'))
      })

      // onSubmit should NOT have been called — validation should have blocked it
      expect(onSubmit).not.toHaveBeenCalled()

      // The form should have errors
      await waitFor(() => {
        const errorsEl = screen.getByTestId('form-errors')

        expect(errorsEl.textContent).not.toBe('{}')
      })
    })
  })

  describe('GIVEN a graduated charge filter with empty properties', () => {
    const emptyGraduatedFilter: ChargeFilterFormValues = {
      chargeModel: ChargeModelEnum.Graduated,
      invoiceDisplayName: '',
      properties: getPropertyShape({}),
      values: [],
    }

    it('THEN submitting should produce validation errors', async () => {
      const onSubmit = jest.fn()

      render(
        <FilterDrawerHarness
          chargeModel={ChargeModelEnum.Graduated}
          initialValues={emptyGraduatedFilter}
          onSubmit={onSubmit}
        />,
      )

      await act(async () => {
        await userEvent.click(screen.getByTestId('submit-btn'))
      })

      expect(onSubmit).not.toHaveBeenCalled()

      await waitFor(() => {
        const errorsEl = screen.getByTestId('form-errors')

        expect(errorsEl.textContent).not.toBe('{}')
      })
    })
  })

  describe('GIVEN a volume charge filter with empty properties', () => {
    const emptyVolumeFilter: ChargeFilterFormValues = {
      chargeModel: ChargeModelEnum.Volume,
      invoiceDisplayName: '',
      properties: getPropertyShape({}),
      values: [],
    }

    it('THEN submitting should produce validation errors', async () => {
      const onSubmit = jest.fn()

      render(
        <FilterDrawerHarness
          chargeModel={ChargeModelEnum.Volume}
          initialValues={emptyVolumeFilter}
          onSubmit={onSubmit}
        />,
      )

      await act(async () => {
        await userEvent.click(screen.getByTestId('submit-btn'))
      })

      expect(onSubmit).not.toHaveBeenCalled()

      await waitFor(() => {
        const errorsEl = screen.getByTestId('form-errors')

        expect(errorsEl.textContent).not.toBe('{}')
      })
    })
  })

  describe('GIVEN the filter drawer has a form wrapper', () => {
    it('THEN pressing Enter in the invoice display name field should submit the form', async () => {
      const onSubmit = jest.fn()

      render(<FilterDrawerHarness onSubmit={onSubmit} />)

      const input = document.querySelector('input[name="invoiceDisplayName"]') as HTMLInputElement

      // Focus the input and press Enter
      await act(async () => {
        input?.focus()
        await userEvent.keyboard('{Enter}')
      })

      // The form's onSubmit handler should have been triggered
      // (validation may prevent the actual onSubmit callback, but the form submission should fire)
      await waitFor(() => {
        const errorsEl = screen.getByTestId('form-errors')

        // Either onSubmit was called (valid form) or errors appeared (invalid form)
        // Both mean the form submission was triggered by Enter
        expect(
          onSubmit.mock.calls.length + (errorsEl.textContent !== '{}' ? 1 : 0),
        ).toBeGreaterThan(0)
      })
    })
  })
})
