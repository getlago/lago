import { configure, render, screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'

import { CURRENCY_PICKER_DATA_TEST } from '../CurrencyPicker'

configure({ testIdAttribute: 'data-test' })

const mockOnChange = jest.fn()
const mockOnClear = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({ debouncedSearch: jest.fn(), isLoading: false }),
}))

jest.mock('~/components/form/ComboBox/ComboBox', () => ({
  ComboBox: ({
    value,
    onChange,
    disableClearable,
    'data-test': dataTest,
  }: {
    value?: string
    onChange: (v: string | null) => void
    disableClearable?: boolean
    'data-test'?: string
  }) => (
    <div data-test={dataTest} data-disable-clearable={String(!!disableClearable)}>
      <span data-test="combo-value">{value ?? ''}</span>
      <button data-test="select-btn" onClick={() => onChange('USD')}>
        Select USD
      </button>
      <button data-test="clear-btn" onClick={() => onChange(null as unknown as string)}>
        Clear
      </button>
    </div>
  ),
}))

describe('CurrencyPicker', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { CurrencyPicker } = require('../CurrencyPicker')

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a CurrencyPicker with a value', () => {
    describe('WHEN it renders', () => {
      it('THEN should display the current value', () => {
        render(<CurrencyPicker value={CurrencyEnum.Eur} onChange={mockOnChange} />)

        expect(screen.getByTestId(CURRENCY_PICKER_DATA_TEST)).toBeInTheDocument()
        expect(screen.getByTestId('combo-value')).toHaveTextContent('EUR')
      })
    })
  })

  describe('GIVEN a CurrencyPicker with onChange', () => {
    describe('WHEN a currency is selected', () => {
      it('THEN should call onChange with the selected currency', () => {
        render(<CurrencyPicker value={undefined} onChange={mockOnChange} />)

        screen.getByTestId('select-btn').click()

        expect(mockOnChange).toHaveBeenCalledWith(CurrencyEnum.Usd)
      })
    })
  })

  describe('GIVEN a CurrencyPicker with onClear provided', () => {
    describe('WHEN the value is cleared', () => {
      it('THEN should call onClear', () => {
        render(
          <CurrencyPicker value={CurrencyEnum.Eur} onChange={mockOnChange} onClear={mockOnClear} />,
        )

        screen.getByTestId('clear-btn').click()

        expect(mockOnClear).toHaveBeenCalled()
        expect(mockOnChange).not.toHaveBeenCalled()
      })

      it('THEN should render with disableClearable false', () => {
        render(
          <CurrencyPicker value={CurrencyEnum.Eur} onChange={mockOnChange} onClear={mockOnClear} />,
        )

        expect(screen.getByTestId(CURRENCY_PICKER_DATA_TEST)).toHaveAttribute(
          'data-disable-clearable',
          'false',
        )
      })
    })
  })

  describe('GIVEN a CurrencyPicker without onClear', () => {
    describe('WHEN it renders', () => {
      it('THEN should have disableClearable set to true', () => {
        render(<CurrencyPicker value={CurrencyEnum.Eur} onChange={mockOnChange} />)

        expect(screen.getByTestId(CURRENCY_PICKER_DATA_TEST)).toHaveAttribute(
          'data-disable-clearable',
          'true',
        )
      })
    })
  })
})
