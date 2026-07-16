import { configure, render } from '@testing-library/react'

configure({ testIdAttribute: 'data-test' })

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
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
  { id: 'entity-3', value: 'code-3', label: 'code-3', name: null, isDefault: false },
]

jest.mock('~/hooks/useBillingEntitiesOptions', () => ({
  useBillingEntitiesOptions: () => ({ options: mockOptions, isLoading: false }),
}))

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { BillingEntityLabel } = require('../BillingEntityLabel')

describe('BillingEntityLabel', () => {
  describe('GIVEN an ownId that matches a billing entity', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the entity name', () => {
        const { container } = render(<BillingEntityLabel ownId="entity-1" />)

        expect(container.textContent).toBe('Entity One')
      })

      it('THEN should fall back to the entity value when name is null', () => {
        const { container } = render(<BillingEntityLabel ownId="entity-3" />)

        expect(container.textContent).toBe('code-3')
      })
    })
  })

  describe('GIVEN no ownId but a customerEntity', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display the customer entity name with inherit suffix', () => {
        const { container } = render(
          <BillingEntityLabel customerEntity={{ name: 'Customer Entity', code: 'cust-code' }} />,
        )

        expect(container.textContent).toBe('Customer Entity (text_1764327933607jgtpungo2pp)')
      })

      it('THEN should fall back to code when name is null', () => {
        const { container } = render(
          <BillingEntityLabel customerEntity={{ name: null, code: 'cust-code' }} />,
        )

        expect(container.textContent).toBe('cust-code (text_1764327933607jgtpungo2pp)')
      })
    })
  })

  describe('GIVEN neither ownId nor customerEntity', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display a dash', () => {
        const { container } = render(<BillingEntityLabel />)

        expect(container.textContent).toBe('-')
      })
    })
  })

  describe('GIVEN null or undefined ownId values', () => {
    describe('WHEN the component renders', () => {
      it.each([
        ['null', null],
        ['undefined', undefined],
        ['empty string', ''],
      ])('THEN should handle %s ownId gracefully', (_label, ownId) => {
        const { container } = render(<BillingEntityLabel ownId={ownId} />)

        expect(container.textContent).toBe('-')
      })
    })
  })
})
