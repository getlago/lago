import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { render } from '~/test-utils'

import {
  PURCHASE_ORDER_ADD_BUTTON_TEST_ID,
  PURCHASE_ORDER_DYNAMIC_INPUT_BUTTON_TEST_ID,
  PURCHASE_ORDER_EDIT_BUTTON_TEST_ID,
  PURCHASE_ORDER_TRASH_BUTTON_TEST_ID,
  PurchaseOrderAddButton,
  PurchaseOrderDynamicInputButton,
  PurchaseOrderEditButton,
  PurchaseOrderTrashButton,
} from '../PurchaseOrderButtons'
import { PurchaseOrderContext } from '../PurchaseOrderContext'
import { PurchaseOrderContextValue } from '../types'

const openEditDialog = jest.fn()
const clearPurchaseOrderNumber = jest.fn()

const buildContext = (
  overrides?: Partial<PurchaseOrderContextValue>,
): PurchaseOrderContextValue => ({
  value: undefined,
  description: undefined,
  disabled: false,
  openEditDialog,
  clearPurchaseOrderNumber,
  ...overrides,
})

const renderWithContext = (ui: ReactNode, context?: Partial<PurchaseOrderContextValue>) =>
  render(
    <PurchaseOrderContext.Provider value={buildContext(context)}>
      {ui}
    </PurchaseOrderContext.Provider>,
  )

describe('PurchaseOrderButtons', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('PurchaseOrderAddButton', () => {
    describe('GIVEN the button is rendered', () => {
      describe('WHEN clicked without a custom onClick', () => {
        it('THEN should call the context openEditDialog', async () => {
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderAddButton />)

          await user.click(screen.getByTestId(PURCHASE_ORDER_ADD_BUTTON_TEST_ID))

          expect(openEditDialog).toHaveBeenCalledTimes(1)
        })
      })

      describe('WHEN a custom onClick is provided', () => {
        it('THEN should call the custom onClick instead of the context handler', async () => {
          const onClick = jest.fn()
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderAddButton onClick={onClick} />)

          await user.click(screen.getByTestId(PURCHASE_ORDER_ADD_BUTTON_TEST_ID))

          expect(onClick).toHaveBeenCalledTimes(1)
          expect(openEditDialog).not.toHaveBeenCalled()
        })
      })

      describe('WHEN custom children are provided', () => {
        it('THEN should render the custom children', () => {
          renderWithContext(<PurchaseOrderAddButton>Custom add label</PurchaseOrderAddButton>)

          expect(screen.getByText('Custom add label')).toBeInTheDocument()
        })
      })

      describe('WHEN disabled via prop or context', () => {
        it.each([
          ['the disabled prop', { disabledProp: true }, undefined],
          ['the context disabled flag', { disabledProp: undefined }, { disabled: true }],
        ])('THEN should be disabled by %s', (_, { disabledProp }, context) => {
          renderWithContext(<PurchaseOrderAddButton disabled={disabledProp} />, context)

          expect(screen.getByTestId(PURCHASE_ORDER_ADD_BUTTON_TEST_ID)).toBeDisabled()
        })
      })
    })
  })

  describe('PurchaseOrderEditButton', () => {
    describe('GIVEN no children are provided', () => {
      describe('WHEN the button renders', () => {
        it('THEN should render the icon button and trigger openEditDialog on click', async () => {
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderEditButton />)

          const button = screen.getByTestId(PURCHASE_ORDER_EDIT_BUTTON_TEST_ID)

          expect(button).toBeInTheDocument()

          await user.click(button)
          expect(openEditDialog).toHaveBeenCalledTimes(1)
        })
      })
    })

    describe('GIVEN children are provided', () => {
      describe('WHEN the button renders', () => {
        it('THEN should render the inline button with the children', () => {
          renderWithContext(<PurchaseOrderEditButton>Edit PO</PurchaseOrderEditButton>)

          const button = screen.getByTestId(PURCHASE_ORDER_EDIT_BUTTON_TEST_ID)

          expect(button).toBeInTheDocument()
          expect(button).toHaveTextContent('Edit PO')
        })
      })

      describe('WHEN a custom onClick is provided', () => {
        it('THEN should call the custom onClick', async () => {
          const onClick = jest.fn()
          const user = userEvent.setup()

          renderWithContext(
            <PurchaseOrderEditButton onClick={onClick}>Edit PO</PurchaseOrderEditButton>,
          )

          await user.click(screen.getByTestId(PURCHASE_ORDER_EDIT_BUTTON_TEST_ID))

          expect(onClick).toHaveBeenCalledTimes(1)
          expect(openEditDialog).not.toHaveBeenCalled()
        })
      })
    })
  })

  describe('PurchaseOrderTrashButton', () => {
    describe('GIVEN the button is rendered', () => {
      describe('WHEN clicked without a custom onClick', () => {
        it('THEN should call the context clearPurchaseOrderNumber', async () => {
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderTrashButton />)

          await user.click(screen.getByTestId(PURCHASE_ORDER_TRASH_BUTTON_TEST_ID))

          expect(clearPurchaseOrderNumber).toHaveBeenCalledTimes(1)
        })
      })

      describe('WHEN a custom onClick is provided', () => {
        it('THEN should call the custom onClick instead of clearing', async () => {
          const onClick = jest.fn()
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderTrashButton onClick={onClick} />)

          await user.click(screen.getByTestId(PURCHASE_ORDER_TRASH_BUTTON_TEST_ID))

          expect(onClick).toHaveBeenCalledTimes(1)
          expect(clearPurchaseOrderNumber).not.toHaveBeenCalled()
        })
      })

      describe('WHEN disabled via context', () => {
        it('THEN should be disabled', () => {
          renderWithContext(<PurchaseOrderTrashButton />, { disabled: true })

          expect(screen.getByTestId(PURCHASE_ORDER_TRASH_BUTTON_TEST_ID)).toBeDisabled()
        })
      })
    })
  })

  describe('PurchaseOrderDynamicInputButton', () => {
    describe('GIVEN the button is rendered', () => {
      describe('WHEN clicked without a custom onClick', () => {
        it('THEN should call the context openEditDialog', async () => {
          const user = userEvent.setup()

          renderWithContext(<PurchaseOrderDynamicInputButton />)

          await user.click(screen.getByTestId(PURCHASE_ORDER_DYNAMIC_INPUT_BUTTON_TEST_ID))

          expect(openEditDialog).toHaveBeenCalledTimes(1)
        })
      })

      describe('WHEN custom children are provided', () => {
        it('THEN should render the custom children', () => {
          renderWithContext(
            <PurchaseOrderDynamicInputButton>Add PO number</PurchaseOrderDynamicInputButton>,
          )

          expect(screen.getByText('Add PO number')).toBeInTheDocument()
        })
      })
    })
  })
})
