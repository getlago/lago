import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  type ChargeForm,
  useChargeFormContext,
  usePropertyValues,
} from '~/contexts/ChargeFormContext'
import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { CUSTOM_CHARGE_JSON_EDITOR_TEST_ID, CustomCharge } from '../CustomCharge'

// --- Mocks ---

const mockSetFieldValue = jest.fn()
const mockOnExpandCustomCharge = jest.fn()

jest.mock('~/contexts/ChargeFormContext', () => ({
  useChargeFormContext: jest.fn(),
  usePropertyValues: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/components/form', () => ({
  JsonEditor: (props: Record<string, unknown>) => (
    <div
      data-test="mock-json-editor"
      data-name={props.name as string}
      data-disabled={String(props.disabled)}
      data-value={props.value as string | undefined}
    >
      {!!props.onExpand && (
        <button
          data-test="mock-json-editor-expand"
          onClick={() => (props.onExpand as () => void)?.()}
        />
      )}
    </div>
  ),
}))

const mockedUseChargeFormContext = useChargeFormContext as jest.MockedFunction<
  typeof useChargeFormContext
>
const mockedUsePropertyValues = usePropertyValues as jest.MockedFunction<typeof usePropertyValues>

// --- Helpers ---

const setupDefaultMocks = (overrides?: { disabled?: boolean; customProperties?: string }) => {
  mockedUseChargeFormContext.mockReturnValue({
    form: {
      setFieldValue: mockSetFieldValue,
    } as unknown as ChargeForm,
    propertyCursor: 'properties',
    currency: CurrencyEnum.Usd,
    disabled: overrides?.disabled ?? false,
    chargePricingUnitShortName: undefined,
  })

  mockedUsePropertyValues.mockReturnValue({
    customProperties: overrides?.customProperties ?? '{"test": true}',
  })
}

// --- Tests ---

describe('CustomCharge', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN it mounts', () => {
      it('THEN should render the JSON editor wrapper', () => {
        render(<CustomCharge />)

        expect(screen.getByTestId(CUSTOM_CHARGE_JSON_EDITOR_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the JSON editor with the correct name', () => {
        render(<CustomCharge />)

        expect(screen.getByTestId('mock-json-editor')).toHaveAttribute(
          'data-name',
          'properties.customProperties',
        )
      })

      it('THEN should render the JSON editor with the current value', () => {
        render(<CustomCharge />)

        expect(screen.getByTestId('mock-json-editor')).toHaveAttribute(
          'data-value',
          '{"test": true}',
        )
      })
    })

    describe('WHEN disabled is false', () => {
      it('THEN should render the JSON editor as enabled', () => {
        render(<CustomCharge />)

        expect(screen.getByTestId('mock-json-editor')).toHaveAttribute('data-disabled', 'false')
      })
    })

    describe('WHEN disabled is true', () => {
      it('THEN should render the JSON editor as disabled', () => {
        setupDefaultMocks({ disabled: true })

        render(<CustomCharge />)

        expect(screen.getByTestId('mock-json-editor')).toHaveAttribute('data-disabled', 'true')
      })
    })
  })

  describe('GIVEN the JSON editor expand action', () => {
    describe('WHEN the expand button is clicked', () => {
      it('THEN should call onExpandCustomCharge with current value', async () => {
        const user = userEvent.setup()

        render(<CustomCharge onExpandCustomCharge={mockOnExpandCustomCharge} />)

        await user.click(screen.getByTestId('mock-json-editor-expand'))

        expect(mockOnExpandCustomCharge).toHaveBeenCalledWith('{"test": true}')
      })
    })

    describe('WHEN onExpandCustomCharge is not provided', () => {
      it('THEN should not render the expand button', () => {
        mockedUseChargeFormContext.mockReturnValue({
          form: { setFieldValue: mockSetFieldValue } as unknown as ChargeForm,
          propertyCursor: 'properties',
          currency: CurrencyEnum.Usd,
          disabled: false,
          chargePricingUnitShortName: undefined,
        })
        mockedUsePropertyValues.mockReturnValue({ customProperties: '{}' })

        render(<CustomCharge />)

        expect(screen.queryByTestId('mock-json-editor-expand')).not.toBeInTheDocument()
      })
    })
  })
})
