import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { act } from 'react'

import { RIGHT_ASIDE_PAGE_HEADER_TEST_ID } from '~/components/layouts/RightAsidePage'
import { render, testMockNavigateFn } from '~/test-utils'

import EditQuote from '../EditQuote'

// --- Shared state for mocks ---

let capturedOnChange: (() => void) | undefined
let mockMarkdownContent = '# Mock markdown content'

type AsideCallbacks = {
  onSaveStart?: () => void
  onSaveFinished?: () => void
  onSaveError?: (payload: unknown) => void
}

let capturedAsideCallbacks: AsideCallbacks = {}

type PricingCommandParams = {
  onSave: (...args: unknown[]) => void
  editData?: unknown
}

let capturedOnPricingCommand: ((params: PricingCommandParams) => void) | undefined
let capturedOnPricingBlocksChange: ((blocks: unknown[]) => void) | undefined
let capturedOnDiscountCommand: ((params: unknown) => void) | undefined
let capturedOnDiscountBlocksChange: ((blocks: unknown[]) => void) | undefined
let capturedEditorCustomerLocale: string | undefined
let capturedEditorCustomerCurrency: string | undefined

// --- Mocks ---

// drawerStack.ts uses import.meta.hot — mock the entire useDrawer module instead
jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
  useFormDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const React = require('react')

  const MockRichTextEditor = ({
    getMarkdownRef,
    onChange,
    onPricingCommand,
    onPricingBlocksChange,
    onDiscountCommand,
    onDiscountBlocksChange,
    customerLocale,
    customerCurrency,
  }: {
    getMarkdownRef?: React.MutableRefObject<(() => string) | null>
    onChange?: () => void
    onPricingCommand?: (params: PricingCommandParams) => void
    onPricingBlocksChange?: (blocks: unknown[]) => void
    onDiscountCommand?: (params: unknown) => void
    onDiscountBlocksChange?: (blocks: unknown[]) => void
    customerLocale?: string
    customerCurrency?: string
  }) => {
    React.useEffect(() => {
      if (getMarkdownRef) {
        getMarkdownRef.current = () => mockMarkdownContent
      }
      capturedOnChange = onChange
      capturedOnPricingCommand = onPricingCommand
      capturedOnPricingBlocksChange = onPricingBlocksChange
      capturedOnDiscountCommand = onDiscountCommand
      capturedOnDiscountBlocksChange = onDiscountBlocksChange
      capturedEditorCustomerLocale = customerLocale
      capturedEditorCustomerCurrency = customerCurrency

      return () => {
        if (getMarkdownRef) {
          getMarkdownRef.current = null
        }
      }
    }, [
      getMarkdownRef,
      onChange,
      onPricingCommand,
      onPricingBlocksChange,
      onDiscountCommand,
      onDiscountBlocksChange,
      customerLocale,
      customerCurrency,
    ])

    return <div data-test="mock-rich-text-editor" />
  }

  return {
    __esModule: true,
    default: MockRichTextEditor,
  }
})

jest.mock('../editQuote/EditQuoteAside', () => {
  return {
    __esModule: true,
    default: (props: {
      isSaving?: boolean
      onSaveStart?: () => void
      onSaveFinished?: () => void
      onSaveError?: (payload: unknown) => void
    }) => {
      capturedAsideCallbacks = {
        onSaveStart: props.onSaveStart,
        onSaveFinished: props.onSaveFinished,
        onSaveError: props.onSaveError,
      }

      return <div data-test="mock-edit-quote-aside" data-is-saving={String(!!props.isSaving)} />
    },
  }
})

const mockUpdateQuoteVersion = jest.fn().mockResolvedValue({})
const mockUpdateQuote = jest.fn().mockResolvedValue({})

let mockIsUpdatingQuoteVersion = false
let mockIsUpdatingQuote = false

let capturedOnUpdateFinished: (() => void) | undefined
let capturedOnUpdateError: (() => void) | undefined

jest.mock('../hooks/useUpdateQuote', () => ({
  useUpdateQuote: (opts?: { onUpdateFinished?: () => void; onUpdateError?: () => void }) => {
    capturedOnUpdateFinished = opts?.onUpdateFinished
    capturedOnUpdateError = opts?.onUpdateError

    return {
      updateQuoteVersion: mockUpdateQuoteVersion,
      isUpdatingQuoteVersion: mockIsUpdatingQuoteVersion,
      isUpdatingQuote: mockIsUpdatingQuote,
      updateQuote: mockUpdateQuote,
    }
  },
}))

const mockQuote = {
  __typename: 'Quote' as const,
  id: 'quote-1',
  number: 'Q-001',
  orderType: 'subscription_creation',
  createdAt: '2026-01-01',
  versions: [
    {
      __typename: 'QuoteVersion' as const,
      id: 'version-1',
      status: 'draft',
      version: 1,
      createdAt: '2026-01-01',
    },
  ],
  customer: {
    __typename: 'Customer' as const,
    id: 'customer-1',
    name: 'Acme Corp',
    externalId: 'ext-cust-1',
    currency: null,
    billingConfiguration: {
      documentLocale: null,
    },
  },
  owners: [{ __typename: 'User' as const, id: 'user-1', email: 'alice@example.com' }],
  subscription: null,
  currentVersion: {
    __typename: 'QuoteVersion' as const,
    id: 'version-1',
    status: 'draft',
    version: 1,
    content: 'Some content',
    currency: null,
    startDate: null,
    endDate: null,
    createdAt: '2026-01-01',
  },
}

const mockRefetchQuote = jest.fn()

const mockUseQuote = jest.fn()

jest.mock('../hooks/useQuote', () => ({
  useQuote: (...args: unknown[]) => mockUseQuote(...args),
}))

const mockDrawerOnPricingCommand = jest.fn()
const mockSyncEntitiesWithBlocks = jest.fn().mockReturnValue(null)
let capturedPricingDrawerArgs: unknown[] = []

jest.mock('../hooks/useSubscriptionPricingDrawer', () => ({
  useSubscriptionPricingDrawer: (...args: unknown[]) => {
    capturedPricingDrawerArgs = args

    return {
      onPricingCommand: mockDrawerOnPricingCommand,
      isPricingDisabled: () => false,
      entities: {},
      syncEntitiesWithBlocks: mockSyncEntitiesWithBlocks,
    }
  },
}))

jest.mock('../hooks/useOneOffPricingDrawer', () => ({
  useOneOffPricingDrawer: () => ({
    onPricingCommand: jest.fn(),
    isPricingDisabled: () => false,
    entities: {},
    syncEntitiesWithBlocks: jest.fn().mockReturnValue(null),
  }),
}))

const mockDiscountOnDiscountCommand = jest.fn()
const mockSyncDiscountBlocks = jest.fn().mockReturnValue(null)

jest.mock('../hooks/useDiscountDrawer', () => ({
  useDiscountDrawer: () => ({
    onDiscountCommand: mockDiscountOnDiscountCommand,
    entities: {},
    syncDiscountBlocks: mockSyncDiscountBlocks,
  }),
}))

jest.mock('../common/getQuoteStatusMapping', () => ({
  getQuoteStatusMapping: () => ({ type: 'outline', label: 'draft' }),
}))

// --- Helpers ---

const getCloseButton = () => {
  const header = screen.getByTestId(RIGHT_ASIDE_PAGE_HEADER_TEST_ID)
  const buttons = header.querySelectorAll('[data-test="button"]')

  return buttons[buttons.length - 1] as HTMLButtonElement
}

// --- Tests ---

describe('EditQuote', () => {
  beforeEach(() => {
    jest.clearAllMocks()

    mockIsUpdatingQuoteVersion = false
    mockIsUpdatingQuote = false
    mockMarkdownContent = '# Mock markdown content'
    capturedOnChange = undefined
    capturedAsideCallbacks = {}
    capturedOnPricingCommand = undefined
    capturedOnPricingBlocksChange = undefined
    capturedOnDiscountCommand = undefined
    capturedOnDiscountBlocksChange = undefined
    capturedEditorCustomerLocale = undefined
    capturedEditorCustomerCurrency = undefined
    capturedPricingDrawerArgs = []
    mockSyncEntitiesWithBlocks.mockReturnValue(null)
    mockSyncDiscountBlocks.mockReturnValue(null)

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ quoteId: 'quote-123' })
    mockUseQuote.mockReturnValue({ quote: mockQuote, loading: false, refetch: mockRefetchQuote })
  })

  describe('GIVEN the quote is loading', () => {
    describe('WHEN rendered', () => {
      it('THEN should not display quote number', () => {
        mockUseQuote.mockReturnValue({ quote: null, loading: true, refetch: jest.fn() })

        render(<EditQuote />)

        expect(screen.queryByText('Q-001 - v1')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the quote is loaded', () => {
    describe('WHEN rendered', () => {
      it('THEN should display quote number and version', () => {
        render(<EditQuote />)

        expect(screen.getByText('Q-001 - v1')).toBeInTheDocument()
      })
    })

    describe('WHEN rendered in idle state', () => {
      it('THEN should display the Saved status chip', () => {
        render(<EditQuote />)

        expect(screen.getByText('text_1779268404389wpd2ysgatw4')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the save encounters an error', () => {
    describe('WHEN onUpdateError is triggered', () => {
      it('THEN should display the error status chip and a retry button', async () => {
        render(<EditQuote />)

        const buttonsBeforeError = screen.getAllByTestId('button').length

        act(() => {
          capturedOnUpdateError?.()
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })

        // The retry icon button should now be present (one more button than before)
        const buttonsAfterError = screen.getAllByTestId('button').length

        expect(buttonsAfterError).toBe(buttonsBeforeError + 1)
      })
    })

    describe('WHEN the retry button is clicked without a stored payload', () => {
      it('THEN should remain in error state since no payload is available', async () => {
        render(<EditQuote />)

        const initialButtons = screen.getAllByTestId('button')

        act(() => {
          capturedOnUpdateError?.()
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })

        // Find the new button that appeared (the retry button)
        const allButtons = screen.getAllByTestId('button')
        const retryButton = allButtons.find((btn) => !initialButtons.includes(btn)) as HTMLElement

        await act(async () => {
          retryButton.click()
        })

        // The retry handler checks failedPayloadRef — with no prior save,
        // it exits early, so the status stays as error
        expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the save succeeds after an error', () => {
    describe('WHEN onUpdateFinished is triggered', () => {
      it('THEN should display the Saved status chip again', async () => {
        render(<EditQuote />)

        act(() => {
          capturedOnUpdateError?.()
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })

        act(() => {
          capturedOnUpdateFinished?.()
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779268404389wpd2ysgatw4')).toBeInTheDocument()
        })

        expect(screen.queryByText('text_1779437694622y666yr137gm')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the close button is clicked', () => {
    describe('WHEN the quote is loaded', () => {
      it('THEN should navigate to the quote details page', async () => {
        const user = userEvent.setup()

        render(<EditQuote />)

        await user.click(getCloseButton())

        expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-123/overview')
      })
    })

    describe('WHEN quoteId is not available', () => {
      it('THEN should not navigate', async () => {
        const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

        useParamsMock.mockReturnValue({})

        const user = userEvent.setup()

        render(<EditQuote />)

        await user.click(getCloseButton())

        expect(testMockNavigateFn).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the editor mode toggle button', () => {
    describe('WHEN the toggle button is clicked', () => {
      it('THEN should switch from edit to preview mode', async () => {
        const user = userEvent.setup()

        render(<EditQuote />)

        // In edit mode, the button shows the preview label
        expect(screen.getByText('text_17792789377356rxkbkmpu81')).toBeInTheDocument()

        // Click the toggle button (the first button in the header children area)
        const toggleButton = screen
          .getByText('text_17792789377356rxkbkmpu81')
          .closest('[data-test="button"]') as HTMLElement

        await user.click(toggleButton)

        // Now in preview mode, the button shows the edit label
        await waitFor(() => {
          expect(screen.getByText('text_1779278937735vlpgsllouzy')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the auto-save flow', () => {
    beforeEach(() => {
      jest.useFakeTimers()
    })

    afterEach(() => {
      jest.useRealTimers()
    })

    describe('WHEN content changes after editor is ready', () => {
      it('THEN should debounce and call updateQuoteVersion', async () => {
        mockUpdateQuoteVersion.mockResolvedValue({
          data: { updateQuoteVersion: { id: 'version-1' } },
        })

        render(<EditQuote />)

        // Let the editor initialize (setTimeout(0) in useEffect)
        await act(async () => {
          jest.advanceTimersByTime(0)
        })

        // Simulate content change
        mockMarkdownContent = '# Updated content'

        act(() => {
          capturedOnChange?.()
        })

        // Should show saving status
        await waitFor(() => {
          expect(screen.getByText('text_1779268404389431dgsiiysk')).toBeInTheDocument()
        })

        // Advance past the debounce delay (2000ms)
        await act(async () => {
          jest.advanceTimersByTime(2000)
        })

        await waitFor(() => {
          expect(mockUpdateQuoteVersion).toHaveBeenCalledWith(
            expect.objectContaining({
              id: 'version-1',
              content: '# Updated content',
            }),
            false,
          )
        })
      })
    })

    describe('WHEN content has not changed from baseline', () => {
      it('THEN should not trigger a save', async () => {
        render(<EditQuote />)

        // Let the editor initialize
        await act(async () => {
          jest.advanceTimersByTime(0)
        })

        // Fire onChange without changing the content
        act(() => {
          capturedOnChange?.()
        })

        // Advance past debounce
        await act(async () => {
          jest.advanceTimersByTime(2000)
        })

        expect(mockUpdateQuoteVersion).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the aside callbacks', () => {
    describe('WHEN onSaveStart is called from the aside', () => {
      it('THEN should set save status to saving', async () => {
        render(<EditQuote />)

        act(() => {
          capturedAsideCallbacks.onSaveStart?.()
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779268404389431dgsiiysk')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN onSaveError is called from the aside with a payload', () => {
      it('THEN should set save status to error', async () => {
        render(<EditQuote />)

        act(() => {
          capturedAsideCallbacks.onSaveError?.({ id: 'version-1', startDate: '2026-01-01' })
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN retry is clicked after aside error stored a payload', () => {
      it('THEN should call updateQuoteVersion with the stored payload', async () => {
        mockUpdateQuoteVersion.mockResolvedValue({
          data: { updateQuoteVersion: { id: 'version-1' } },
        })

        render(<EditQuote />)

        const initialButtons = screen.getAllByTestId('button')

        // Trigger error from aside with a payload — this stores it in failedPayloadRef
        act(() => {
          capturedAsideCallbacks.onSaveError?.({ id: 'version-1', startDate: '2026-06-01' })
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })

        // Find and click the retry button
        const allButtons = screen.getAllByTestId('button')
        const retryButton = allButtons.find((btn) => !initialButtons.includes(btn)) as HTMLElement

        await act(async () => {
          retryButton.click()
        })

        await waitFor(() => {
          expect(mockUpdateQuoteVersion).toHaveBeenCalledWith(
            expect.objectContaining({ id: 'version-1', startDate: '2026-06-01' }),
            false,
          )
        })
      })
    })
  })

  describe('GIVEN the isSaving prop passed to the aside', () => {
    const getAside = () => screen.getByTestId('mock-edit-quote-aside')

    describe('WHEN the save status is idle', () => {
      it('THEN should pass isSaving=false to the aside', () => {
        render(<EditQuote />)

        expect(getAside()).toHaveAttribute('data-is-saving', 'false')
      })
    })

    describe('WHEN a save starts', () => {
      it('THEN should pass isSaving=true to the aside', async () => {
        render(<EditQuote />)

        act(() => {
          capturedAsideCallbacks.onSaveStart?.()
        })

        await waitFor(() => {
          expect(getAside()).toHaveAttribute('data-is-saving', 'true')
        })
      })
    })

    describe('WHEN a save finishes successfully', () => {
      it('THEN should pass isSaving=false back to the aside', async () => {
        render(<EditQuote />)

        act(() => {
          capturedAsideCallbacks.onSaveStart?.()
        })

        await waitFor(() => {
          expect(getAside()).toHaveAttribute('data-is-saving', 'true')
        })

        act(() => {
          capturedAsideCallbacks.onSaveFinished?.()
        })

        await waitFor(() => {
          expect(getAside()).toHaveAttribute('data-is-saving', 'false')
        })
      })
    })

    describe('WHEN a save errors', () => {
      it('THEN should pass isSaving=false back to the aside', async () => {
        render(<EditQuote />)

        act(() => {
          capturedAsideCallbacks.onSaveStart?.()
        })

        await waitFor(() => {
          expect(getAside()).toHaveAttribute('data-is-saving', 'true')
        })

        act(() => {
          capturedAsideCallbacks.onSaveError?.({ id: 'version-1' })
        })

        await waitFor(() => {
          expect(getAside()).toHaveAttribute('data-is-saving', 'false')
        })
      })
    })
  })

  describe('GIVEN the close button disabled state', () => {
    describe('WHEN a mutation is in progress', () => {
      it('THEN should disable the close button', () => {
        mockIsUpdatingQuoteVersion = true

        render(<EditQuote />)

        expect(getCloseButton()).toBeDisabled()
      })
    })
  })

  describe('GIVEN the pricing block integration', () => {
    describe('WHEN handlePricingCommand is invoked from the editor', () => {
      it('THEN should delegate to usePricingDrawer onPricingCommand with editData', () => {
        render(<EditQuote />)

        const mockEditData = { pricingType: 'plan' as const, entityIds: ['plan-1'] }

        act(() => {
          capturedOnPricingCommand?.({ onSave: jest.fn(), editData: mockEditData })
        })

        expect(mockDrawerOnPricingCommand).toHaveBeenCalledWith(
          expect.objectContaining({ editData: mockEditData }),
        )
      })
    })

    describe('WHEN the pricing drawer onSave fires successfully', () => {
      it('THEN should call the original onSave and save content with billingItems', async () => {
        mockUpdateQuoteVersion.mockResolvedValue({
          data: { updateQuoteVersion: { id: 'version-1' } },
        })

        render(<EditQuote />)

        const mockOriginalOnSave = jest.fn()

        act(() => {
          capturedOnPricingCommand?.({ onSave: mockOriginalOnSave })
        })

        // Extract the wrapped onSave that was passed to the drawer hook
        const wrappedOnSave = mockDrawerOnPricingCommand.mock.calls[0][0].onSave
        const mockAttrs = { pricingType: 'addOns', entityIds: ['addon-1'] }
        const mockEntityData = { 'addon-1': { name: 'Test Add-on' } }
        const mockBillingItems = { addons: [{ addOnId: 'addon-1' }] }

        await act(async () => {
          wrappedOnSave(mockAttrs, mockEntityData, mockBillingItems)
        })

        // Original onSave should be called with all arguments
        expect(mockOriginalOnSave).toHaveBeenCalledWith(mockAttrs, mockEntityData, mockBillingItems)

        // savePricingBlock should trigger updateQuoteVersion with content + billingItems
        await waitFor(() => {
          expect(mockUpdateQuoteVersion).toHaveBeenCalledWith(
            expect.objectContaining({
              id: 'version-1',
              content: mockMarkdownContent,
              billingItems: mockBillingItems,
            }),
            false,
          )
        })

        // On success, refetchQuote should be called
        await waitFor(() => {
          expect(mockRefetchQuote).toHaveBeenCalled()
        })
      })
    })

    describe('WHEN savePricingBlock fails', () => {
      it('THEN should set save status to error', async () => {
        mockUpdateQuoteVersion.mockRejectedValue(new Error('Network error'))

        render(<EditQuote />)

        act(() => {
          capturedOnPricingCommand?.({ onSave: jest.fn() })
        })

        const wrappedOnSave = mockDrawerOnPricingCommand.mock.calls[0][0].onSave

        await act(async () => {
          wrappedOnSave({}, {}, [{ addOnId: 'addon-1' }])
        })

        await waitFor(() => {
          expect(screen.getByText('text_1779437694622y666yr137gm')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN pricing blocks change and syncEntitiesWithBlocks returns billing items', () => {
      it('THEN should save the updated billing items', async () => {
        const mockBillingItems = { addons: [{ addOnId: 'addon-1', units: '2' }] }

        mockSyncEntitiesWithBlocks.mockReturnValue(mockBillingItems)
        mockUpdateQuoteVersion.mockResolvedValue({
          data: { updateQuoteVersion: { id: 'version-1' } },
        })

        render(<EditQuote />)

        const mockBlocks = [{ pricingType: 'addOns', entityIds: ['addon-1'] }]

        await act(async () => {
          capturedOnPricingBlocksChange?.(mockBlocks)
        })

        expect(mockSyncEntitiesWithBlocks).toHaveBeenCalledWith(mockBlocks)

        await waitFor(() => {
          expect(mockUpdateQuoteVersion).toHaveBeenCalledWith(
            expect.objectContaining({ billingItems: mockBillingItems }),
            false,
          )
        })
      })
    })

    describe('WHEN pricing blocks change but syncEntitiesWithBlocks returns null', () => {
      it('THEN should not trigger a save', async () => {
        mockSyncEntitiesWithBlocks.mockReturnValue(null)

        render(<EditQuote />)

        const mockBlocks = [{ pricingType: 'plan', entityIds: ['plan-1'] }]

        await act(async () => {
          capturedOnPricingBlocksChange?.(mockBlocks)
        })

        expect(mockSyncEntitiesWithBlocks).toHaveBeenCalledWith(mockBlocks)
        expect(mockUpdateQuoteVersion).not.toHaveBeenCalled()
      })
    })

    describe('WHEN savePricingBlock is called without a versionId', () => {
      it('THEN should not call updateQuoteVersion', async () => {
        const quoteWithoutVersion = {
          ...mockQuote,
          currentVersion: { ...mockQuote.currentVersion, id: undefined },
        }

        mockUseQuote.mockReturnValue({
          quote: quoteWithoutVersion,
          loading: false,
          refetch: mockRefetchQuote,
        })

        render(<EditQuote />)

        act(() => {
          capturedOnPricingCommand?.({ onSave: jest.fn() })
        })

        const wrappedOnSave = mockDrawerOnPricingCommand.mock.calls[0][0].onSave

        await act(async () => {
          wrappedOnSave({}, {}, [{ addOnId: 'addon-1' }])
        })

        expect(mockUpdateQuoteVersion).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN customer locale and currency props', () => {
    describe('WHEN the customer has a document locale', () => {
      it('THEN should pass customerLocale to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            customer: {
              ...mockQuote.customer,
              billingConfiguration: { documentLocale: 'fr' },
            },
          },
          loading: false,
          refetch: mockRefetchQuote,
        })

        render(<EditQuote />)

        expect(capturedEditorCustomerLocale).toBe('fr')
      })
    })

    describe('WHEN the customer has no document locale', () => {
      it('THEN should default customerLocale to en', () => {
        render(<EditQuote />)

        expect(capturedEditorCustomerLocale).toBe('en')
      })
    })

    describe('WHEN the customer has a currency', () => {
      it('THEN should pass customerCurrency to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            customer: {
              ...mockQuote.customer,
              currency: 'EUR',
            },
          },
          loading: false,
          refetch: mockRefetchQuote,
        })

        render(<EditQuote />)

        expect(capturedEditorCustomerCurrency).toBe('EUR')
      })
    })

    describe('WHEN the customer has no currency', () => {
      it('THEN should pass undefined customerCurrency to RichTextEditor', () => {
        render(<EditQuote />)

        expect(capturedEditorCustomerCurrency).toBeUndefined()
      })
    })

    describe('WHEN the customer has a currency', () => {
      it('THEN should pass the customer to useSubscriptionPricingDrawer options', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            customer: {
              ...mockQuote.customer,
              currency: 'EUR',
            },
          },
          loading: false,
          refetch: mockRefetchQuote,
        })

        render(<EditQuote />)

        const options = capturedPricingDrawerArgs[1] as { customer?: { currency?: string } }

        expect(options.customer?.currency).toBe('EUR')
      })
    })
  })

  describe('GIVEN the discount command integration', () => {
    describe('WHEN the quote is a subscription order', () => {
      it('THEN should pass a defined onDiscountCommand to RichTextEditor', () => {
        // mockQuote.orderType = 'subscription_creation' by default
        render(<EditQuote />)

        expect(capturedOnDiscountCommand).toBeDefined()
      })
    })

    describe('WHEN the quote is a one-off order', () => {
      it('THEN should pass undefined onDiscountCommand to RichTextEditor', () => {
        mockUseQuote.mockReturnValue({
          quote: {
            ...mockQuote,
            orderType: 'one_off',
          },
          loading: false,
          refetch: mockRefetchQuote,
        })

        render(<EditQuote />)

        expect(capturedOnDiscountCommand).toBeUndefined()
      })
    })

    describe('WHEN handleDiscountCommand is invoked from the editor', () => {
      it('THEN should delegate to useDiscountDrawer onDiscountCommand with editData', () => {
        render(<EditQuote />)

        const mockEditData = { couponId: 'coupon-1', localId: 'local-1' }

        act(() => {
          capturedOnDiscountCommand?.({ onSave: jest.fn(), editData: mockEditData })
        })

        expect(mockDiscountOnDiscountCommand).toHaveBeenCalledWith(
          expect.objectContaining({ editData: mockEditData }),
        )
      })
    })

    describe('WHEN discount blocks change and syncDiscountBlocks returns billing items', () => {
      it('THEN should save the updated billing items', async () => {
        // The discount drawer owns only the `coupons` key and returns a partial
        // without `addons`; savePricingBlock normalizes `addons` back in.
        const mockBillingItems = { coupons: [{ id: 'coupon-1', position: 1 }] }

        mockSyncDiscountBlocks.mockReturnValue(mockBillingItems)
        mockUpdateQuoteVersion.mockResolvedValue({
          data: { updateQuoteVersion: { id: 'version-1' } },
        })

        render(<EditQuote />)

        const mockBlocks = [{ couponId: 'coupon-1', localId: 'local-1' }]

        await act(async () => {
          capturedOnDiscountBlocksChange?.(mockBlocks)
        })

        expect(mockSyncDiscountBlocks).toHaveBeenCalledWith(mockBlocks)

        await waitFor(() => {
          expect(mockUpdateQuoteVersion).toHaveBeenCalledWith(
            expect.objectContaining({
              billingItems: { addons: [], coupons: [{ id: 'coupon-1', position: 1 }] },
            }),
            false,
          )
        })
      })
    })

    describe('WHEN discount blocks change but syncDiscountBlocks returns null', () => {
      it('THEN should not trigger a save', async () => {
        mockSyncDiscountBlocks.mockReturnValue(null)

        render(<EditQuote />)

        const mockBlocks = [{ couponId: 'coupon-1', localId: 'local-1' }]

        await act(async () => {
          capturedOnDiscountBlocksChange?.(mockBlocks)
        })

        expect(mockSyncDiscountBlocks).toHaveBeenCalledWith(mockBlocks)
        expect(mockUpdateQuoteVersion).not.toHaveBeenCalled()
      })
    })
  })
})
