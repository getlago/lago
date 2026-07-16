import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { PurchaseOrderContext, usePurchaseOrderContext } from '../PurchaseOrderContext'
import { PurchaseOrderContextValue } from '../types'

const CONSUMER_TEST_ID = 'context-consumer'

const Consumer = () => {
  const context = usePurchaseOrderContext()

  return <div data-test={CONSUMER_TEST_ID}>{context.value}</div>
}

describe('usePurchaseOrderContext', () => {
  describe('GIVEN the hook is used outside of a provider', () => {
    describe('WHEN the consumer renders', () => {
      it('THEN should throw a descriptive error', () => {
        // Silence the expected React error boundary logging for this render
        const consoleError = jest.spyOn(console, 'error').mockImplementation(() => undefined)

        expect(() => render(<Consumer />)).toThrow(
          'PO compound components must be used inside <PO>.',
        )

        consoleError.mockRestore()
      })
    })
  })

  describe('GIVEN the hook is used inside a provider', () => {
    describe('WHEN the consumer renders', () => {
      it('THEN should return the provided context value', () => {
        const contextValue: PurchaseOrderContextValue = {
          value: 'PO-999',
          description: undefined,
          disabled: false,
          openEditDialog: jest.fn(),
          clearPurchaseOrderNumber: jest.fn(),
        }

        render(
          <PurchaseOrderContext.Provider value={contextValue}>
            <Consumer />
          </PurchaseOrderContext.Provider>,
        )

        expect(screen.getByTestId(CONSUMER_TEST_ID)).toHaveTextContent('PO-999')
      })
    })
  })
})
