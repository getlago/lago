import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME, FORM_DIALOG_TEST_ID } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { render } from '~/test-utils'

import { normalizePurchaseOrderNumber, PO } from '../PO'
import {
  PURCHASE_ORDER_ADD_BUTTON_TEST_ID,
  PURCHASE_ORDER_EDIT_BUTTON_TEST_ID,
  PURCHASE_ORDER_TRASH_BUTTON_TEST_ID,
} from '../PurchaseOrderButtons'
import { PURCHASE_ORDER_DESCRIPTION_TEST_ID } from '../PurchaseOrderDescription'
import { PURCHASE_ORDER_NUMBER_TEST_ID } from '../PurchaseOrderNumber'
import { PURCHASE_ORDER_ROOT_TEST_ID } from '../PurchaseOrderRoot'
import { PURCHASE_ORDER_TITLE_TEST_ID } from '../PurchaseOrderTitle'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => (
  <NiceModal.Provider>{children}</NiceModal.Provider>
)

describe('PO compound component', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the compound API', () => {
    describe('WHEN accessing its parts', () => {
      it.each([
        ['Title', PO.Title],
        ['Description', PO.Description],
        ['Number', PO.Number],
        ['AddButton', PO.AddButton],
        ['EditButton', PO.EditButton],
        ['TrashButton', PO.TrashButton],
        ['DynamicInputButton', PO.DynamicInputButton],
      ])('THEN should expose the %s sub-component', (_, part) => {
        expect(part).toBeDefined()
      })

      it('THEN should re-export the normalize helper', () => {
        expect(normalizePurchaseOrderNumber('  PO-1  ')).toBe('PO-1')
      })
    })
  })

  describe('GIVEN a PO with a value', () => {
    describe('WHEN it renders the root, title and number', () => {
      it('THEN should render the root container', () => {
        render(
          <NiceModalWrapper>
            <PO value="PO-123">
              <PO.Title />
              <PO.Number />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_ROOT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the title', () => {
        render(
          <NiceModalWrapper>
            <PO value="PO-123">
              <PO.Title />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_TITLE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the normalized number value', () => {
        render(
          <NiceModalWrapper>
            <PO value="  PO-123  ">
              <PO.Number />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_NUMBER_TEST_ID)).toHaveTextContent('PO-123')
      })
    })
  })

  describe('GIVEN a PO without a value', () => {
    describe('WHEN the number renders', () => {
      it('THEN should render the default placeholder', () => {
        render(
          <NiceModalWrapper>
            <PO value={null}>
              <PO.Number />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_NUMBER_TEST_ID)).toHaveTextContent('-')
      })

      it('THEN should render a custom placeholder when provided', () => {
        render(
          <NiceModalWrapper>
            <PO value={null}>
              <PO.Number placeholder="No PO" />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_NUMBER_TEST_ID)).toHaveTextContent('No PO')
      })
    })
  })

  describe('GIVEN the description sub-component', () => {
    describe('WHEN a description is provided on the root', () => {
      it('THEN should render the root description', () => {
        render(
          <NiceModalWrapper>
            <PO value={null} description="Displayed on the invoice">
              <PO.Description />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_DESCRIPTION_TEST_ID)).toHaveTextContent(
          'Displayed on the invoice',
        )
      })
    })

    describe('WHEN children are provided directly', () => {
      it('THEN should render the children over the root description', () => {
        render(
          <NiceModalWrapper>
            <PO value={null} description="Root description">
              <PO.Description>Override description</PO.Description>
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_DESCRIPTION_TEST_ID)).toHaveTextContent(
          'Override description',
        )
      })
    })

    describe('WHEN neither description nor children are provided', () => {
      it('THEN should render nothing', () => {
        render(
          <NiceModalWrapper>
            <PO value={null}>
              <PO.Description />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.queryByTestId(PURCHASE_ORDER_DESCRIPTION_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the disabled flag is set on the root', () => {
    describe('WHEN the add button renders', () => {
      it('THEN should disable the add button', () => {
        render(
          <NiceModalWrapper>
            <PO value={null} disabled>
              <PO.AddButton />
            </PO>
          </NiceModalWrapper>,
        )

        expect(screen.getByTestId(PURCHASE_ORDER_ADD_BUTTON_TEST_ID)).toBeDisabled()
      })
    })
  })

  describe('GIVEN a value is set', () => {
    describe('WHEN the trash button is clicked', () => {
      it('THEN should call onChange with null', async () => {
        const onChange = jest.fn()
        const user = userEvent.setup()

        render(
          <NiceModalWrapper>
            <PO value="PO-123" onChange={onChange}>
              <PO.TrashButton />
            </PO>
          </NiceModalWrapper>,
        )

        await user.click(screen.getByTestId(PURCHASE_ORDER_TRASH_BUTTON_TEST_ID))

        expect(onChange).toHaveBeenCalledWith(null)
      })
    })
  })

  describe('GIVEN the edit/add flow', () => {
    describe('WHEN the add button is clicked', () => {
      it('THEN should open the form dialog', async () => {
        const user = userEvent.setup()

        render(
          <NiceModalWrapper>
            <PO value={null}>
              <PO.AddButton />
            </PO>
          </NiceModalWrapper>,
        )

        await user.click(screen.getByTestId(PURCHASE_ORDER_ADD_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
        })
      })
    })

    describe('WHEN the edit button is clicked', () => {
      it('THEN should open the form dialog', async () => {
        const user = userEvent.setup()

        render(
          <NiceModalWrapper>
            <PO value="PO-123">
              <PO.EditButton />
            </PO>
          </NiceModalWrapper>,
        )

        await user.click(screen.getByTestId(PURCHASE_ORDER_EDIT_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
        })
      })
    })
  })
})
