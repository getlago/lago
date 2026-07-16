import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import BillingEntityCreateEdit from '../BillingEntityCreateEdit'

const PHONE_PLACEHOLDER = 'Type a phone number'
const SAVE_EDITS_LABEL = 'Save edits'

const mockOnSave = jest.fn()
const mockOnClose = jest.fn()

type HookReturn = ReturnType<typeof import('~/hooks/useCreateEditBillingEntity').default>

let mockHookReturn: HookReturn

jest.mock('~/hooks/useCreateEditBillingEntity', () => ({
  __esModule: true,
  default: jest.fn(() => mockHookReturn),
}))

const baseBillingEntity = (overrides = {}) =>
  ({
    id: 'test-id',
    code: 'test-entity',
    name: 'Test Entity',
    email: 'test@example.com',
    phone: '+49 30 123456',
    addressLine1: '1 Test St',
    country: 'DE',
    einvoicing: false,
    ...overrides,
  }) as unknown as HookReturn['billingEntity']

const setHook = (overrides: Partial<HookReturn> = {}) => {
  mockHookReturn = {
    loading: false,
    isEdition: false,
    billingEntity: undefined,
    errorCode: undefined,
    onClose: mockOnClose,
    onSave: mockOnSave,
    ...overrides,
  } as HookReturn
}

describe('BillingEntityCreateEdit - phone field', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders the phone input on the create form', async () => {
    setHook()

    await act(async () => {
      render(<BillingEntityCreateEdit />)
    })

    expect(screen.getByPlaceholderText(PHONE_PLACEHOLDER)).toBeInTheDocument()
  })

  it('pre-fills the existing phone on the edit form', async () => {
    setHook({ isEdition: true, billingEntity: baseBillingEntity() })

    await act(async () => {
      render(<BillingEntityCreateEdit />)
    })

    expect(screen.getByPlaceholderText(PHONE_PLACEHOLDER)).toHaveValue('+49 30 123456')
  })

  it('submits the entered phone value', async () => {
    setHook({ isEdition: true, billingEntity: baseBillingEntity({ phone: null }) })

    await act(async () => {
      render(<BillingEntityCreateEdit />)
    })

    const phoneInput = screen.getByPlaceholderText(PHONE_PLACEHOLDER)

    await userEvent.type(phoneInput, '+33 6 11 22 33 44')
    await userEvent.click(screen.getByRole('button', { name: SAVE_EDITS_LABEL }))

    await waitFor(() => {
      expect(mockOnSave).toHaveBeenCalledWith(
        expect.objectContaining({ phone: '+33 6 11 22 33 44' }),
      )
    })
  })

  it('submits null when the phone is cleared', async () => {
    setHook({ isEdition: true, billingEntity: baseBillingEntity() })

    await act(async () => {
      render(<BillingEntityCreateEdit />)
    })

    const phoneInput = screen.getByPlaceholderText(PHONE_PLACEHOLDER)

    await userEvent.clear(phoneInput)
    await userEvent.click(screen.getByRole('button', { name: SAVE_EDITS_LABEL }))

    await waitFor(() => {
      expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ phone: null }))
    })
  })
})
