import { configure, render, screen } from '@testing-library/react'

import { FeatureFlagEnum } from '~/generated/graphql'

import { BILLING_ENTITY_FORM_PICKER_DATA_TEST } from '../BillingEntityFormPicker'

configure({ testIdAttribute: 'data-test' })

const mockOnChange = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const mockHasFeatureFlag = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
  }),
}))

const mockOptions = [
  {
    id: 'entity-1',
    value: 'code-1',
    label: 'Entity One (default)',
    name: 'Entity One',
    isDefault: true,
  },
  { id: 'entity-2', value: 'code-2', label: 'Entity Two', name: 'Entity Two', isDefault: false },
]

jest.mock('~/hooks/useBillingEntitiesOptions', () => ({
  useBillingEntitiesOptions: () => ({
    options: mockOptions,
    isLoading: false,
  }),
}))

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({ debouncedSearch: jest.fn(), isLoading: false }),
}))

jest.mock('~/components/form/ComboBox/ComboBox', () => ({
  ComboBox: ({
    value,
    onChange,
    'data-test': dataTest,
    data,
  }: {
    value?: string
    onChange: (v: string) => void
    'data-test'?: string
    data?: Array<{ id: string; value: string }>
  }) => (
    <div data-test={dataTest}>
      <span data-test="combo-value">{value ?? ''}</span>
      {data?.map((item) => (
        <button
          key={item.value}
          data-test={`option-${item.value}`}
          onClick={() => onChange(item.value)}
        >
          {item.value}
        </button>
      ))}
    </div>
  ),
}))

describe('BillingEntityFormPicker', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { BillingEntityFormPicker } = require('../BillingEntityFormPicker')

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the multi_entity_billing feature flag is disabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN should return null', () => {
        mockHasFeatureFlag.mockReturnValue(false)

        const { container } = render(
          <BillingEntityFormPicker value={undefined} onChange={mockOnChange} />,
        )

        expect(container.firstChild).toBeNull()
      })
    })
  })

  describe('GIVEN the multi_entity_billing feature flag is enabled', () => {
    beforeEach(() => {
      mockHasFeatureFlag.mockImplementation(
        (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiEntityBilling,
      )
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the picker', () => {
        render(<BillingEntityFormPicker value="entity-1" onChange={mockOnChange} />)

        expect(screen.getByTestId(BILLING_ENTITY_FORM_PICKER_DATA_TEST)).toBeInTheDocument()
      })

      it('THEN should resolve the current value to its code', () => {
        render(<BillingEntityFormPicker value="entity-1" onChange={mockOnChange} />)

        expect(screen.getByTestId('combo-value')).toHaveTextContent('code-1')
      })
    })

    describe('WHEN a code is selected', () => {
      it('THEN should call onChange with the corresponding entity id', () => {
        render(<BillingEntityFormPicker value={undefined} onChange={mockOnChange} />)

        screen.getByTestId('option-code-2').click()

        expect(mockOnChange).toHaveBeenCalledWith('entity-2')
      })
    })
  })
})
