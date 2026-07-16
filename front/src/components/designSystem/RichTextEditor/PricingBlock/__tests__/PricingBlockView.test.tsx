import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { NodeViewProps } from '@tiptap/react'

import type { Locale } from '~/core/translations'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  EntityData,
  OnPricingCommand,
  RichTextEditorProvider,
} from '../../common/RichTextEditorContext'
import { SLASH_COMMAND_BLOCK_VIEW_TEST_ID } from '../../SlashCommandBlockWrapper/SlashCommandBlockWrapper'
import { ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID } from '../OneOffAddOnsPreviewTable'
import {
  PRICING_BLOCK_VIEW_EMPTY_TEST_ID,
  PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID,
  PricingBlockView,
} from '../PricingBlockView'
import { SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID } from '../SubscriptionPlanPreviewTable'

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  NodeViewWrapper: ({
    children,
    ...props
  }: {
    children: React.ReactNode
    as?: string
    className?: string
  }) => <div {...props}>{children}</div>,
}))

const createNodeProps = (
  attrs: Record<string, unknown> = {},
  overrides: Partial<NodeViewProps> = {},
): NodeViewProps => {
  return {
    node: {
      attrs: { pricingType: 'plan', entityIds: [], ...attrs },
    },
    editor: null as never,
    extension: null as never,
    getPos: () => 0,
    updateAttributes: jest.fn(),
    deleteNode: () => {},
    selected: false,
    decorations: [],
    innerDecorations: null as never,
    HTMLAttributes: {},
    view: null as never,
    ...overrides,
  } as unknown as NodeViewProps
}

const renderPricingBlockView = ({
  attrs = {},
  mode = 'edit' as 'edit' | 'preview',
  entities = {} as Record<string, EntityData>,
  onPricingCommand = jest.fn() as OnPricingCommand,
  customerLocale,
  customerCurrency,
}: {
  attrs?: Record<string, unknown>
  mode?: 'edit' | 'preview'
  entities?: Record<string, EntityData>
  onPricingCommand?: OnPricingCommand
  customerLocale?: Locale
  customerCurrency?: CurrencyEnum
} = {}) => {
  const nodeProps = createNodeProps(attrs)

  return {
    ...render(
      <RichTextEditorProvider
        value={{
          mode,
          mentionValues: {},
          entities,
          images: {},
          onPricingCommand,
          customerLocale,
          customerCurrency,
        }}
      >
        <PricingBlockView {...nodeProps} />
      </RichTextEditorProvider>,
    ),
    nodeProps,
    onPricingCommand,
  }
}

describe('PricingBlockView', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is in edit mode', () => {
    describe('WHEN rendered with empty entityIds', () => {
      it('THEN should display the empty state button', () => {
        renderPricingBlockView()

        expect(screen.getByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should show the placeholder text', () => {
        renderPricingBlockView()

        const emptyButton = screen.getByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)

        expect(emptyButton).toHaveTextContent('Select pricing')
      })
    })

    describe('WHEN rendered with entityIds that have context data (plan)', () => {
      it('THEN should display the plan name as the main text and the code in the caption', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['plan-1'] },
          entities: {
            'plan-1': {
              entityId: 'plan-1',
              entityType: 'plan',
              name: 'Basic Plan',
              code: 'basic',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        expect(button).toHaveTextContent('Basic Plan')
        expect(within(button).getByTestId('caption')).toHaveTextContent('basic')
      })

      it('THEN should render the plan (board) icon', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['plan-1'] },
          entities: {
            'plan-1': {
              entityId: 'plan-1',
              entityType: 'plan',
              name: 'Basic Plan',
              code: 'basic',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        expect(within(button).getByTestId('board/medium')).toBeInTheDocument()
      })
    })

    describe('WHEN rendered with entityIds that have context data (addOns)', () => {
      it('THEN should display each add-on name', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'addOns', entityIds: ['addon-1', 'addon-2'] },
          entities: {
            'addon-1': {
              entityId: 'addon-1',
              entityType: 'addOn',
              name: 'Storage Add-on',
              code: 'storage',
            },
            'addon-2': {
              entityId: 'addon-2',
              entityType: 'addOn',
              name: 'Support Add-on',
              code: 'support',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        expect(button).toHaveTextContent('One-off invoice of')
        expect(button).toHaveTextContent('Click to edit')
      })

      it('THEN should render the add-ons (document) icon and no plan code prefix', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'addOns', entityIds: ['addon-1'] },
          entities: {
            'addon-1': {
              entityId: 'addon-1',
              entityType: 'addOn',
              name: 'Storage Add-on',
              code: 'storage',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        expect(within(button).getByTestId('document/medium')).toBeInTheDocument()
        expect(within(button).getByTestId('caption')).not.toHaveTextContent('•')
      })
    })

    describe('WHEN rendered with entityIds that have no context data (plan)', () => {
      it('THEN should display the unresolved view with plan id', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['plan-123'] },
        })

        expect(screen.getByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).toHaveTextContent(
          'Plan: plan-123',
        )
      })
    })

    describe('WHEN rendered with entityIds that have no context data (addOns)', () => {
      it('THEN should display the unresolved view with add-on ids', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'addOns', entityIds: ['addon-1', 'addon-2'] },
        })

        expect(screen.getByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).toHaveTextContent(
          'Add-ons: addon-1, addon-2',
        )
      })
    })

    describe('WHEN the empty state button is clicked', () => {
      it('THEN should call onPricingCommand with editData undefined', async () => {
        const user = userEvent.setup()
        const { onPricingCommand } = renderPricingBlockView()

        const button = screen.getByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)

        await user.click(button)

        expect(onPricingCommand).toHaveBeenCalledWith(
          expect.objectContaining({
            onSave: expect.any(Function),
            editData: undefined,
          }),
        )
      })
    })

    describe('WHEN the resolved plan block is clicked', () => {
      it('THEN should call onPricingCommand with editData containing pricingType and entityIds', async () => {
        const user = userEvent.setup()
        const { onPricingCommand } = renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['plan-1'] },
          entities: {
            'plan-1': {
              entityId: 'plan-1',
              entityType: 'plan',
              name: 'Basic Plan',
              code: 'basic',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)

        await user.click(button)

        expect(onPricingCommand).toHaveBeenCalledWith(
          expect.objectContaining({
            onSave: expect.any(Function),
            editData: { pricingType: 'plan', entityIds: ['plan-1'], localEntityIds: [] },
          }),
        )
      })
    })

    describe('WHEN onSave is called from the pricing command params', () => {
      it('THEN should call updateAttributes with the new attrs', async () => {
        const user = userEvent.setup()
        const mockOnPricingCommand = jest.fn()
        const { nodeProps } = renderPricingBlockView({
          onPricingCommand: mockOnPricingCommand,
        })

        const button = screen.getByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)

        await user.click(button)

        const { onSave } = mockOnPricingCommand.mock.calls[0][0]
        const newAttrs = { pricingType: 'plan' as const, entityIds: ['plan-new'] }

        onSave(newAttrs, {})

        expect(nodeProps.updateAttributes).toHaveBeenCalledWith(newAttrs)
      })
    })

    describe('WHEN the unresolved state is rendered', () => {
      it('THEN should not be clickable', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['unknown-plan'] },
        })

        const unresolvedElement = screen.getByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)

        // The unresolved element should be a div, not a button
        expect(unresolvedElement.tagName).not.toBe('BUTTON')
      })
    })

    describe('WHEN mouseDown occurs on the empty pricing block button', () => {
      it('THEN should stop propagation to prevent BlockToolbar overlay', () => {
        renderPricingBlockView()

        const button = screen.getByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)
        const mouseDownEvent = new MouseEvent('mousedown', { bubbles: true, cancelable: true })
        const stopPropagationSpy = jest.spyOn(mouseDownEvent, 'stopPropagation')

        button.dispatchEvent(mouseDownEvent)

        expect(stopPropagationSpy).toHaveBeenCalled()
      })
    })

    describe('WHEN mouseDown occurs on the resolved pricing block button', () => {
      it('THEN should stop propagation to prevent BlockToolbar overlay', () => {
        renderPricingBlockView({
          attrs: { pricingType: 'plan', entityIds: ['plan-1'] },
          entities: {
            'plan-1': {
              entityId: 'plan-1',
              entityType: 'plan',
              name: 'Basic Plan',
              code: 'basic',
            },
          },
        })

        const button = screen.getByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)
        const mouseDownEvent = new MouseEvent('mousedown', { bubbles: true, cancelable: true })
        const stopPropagationSpy = jest.spyOn(mouseDownEvent, 'stopPropagation')

        button.dispatchEvent(mouseDownEvent)

        expect(stopPropagationSpy).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the component is in preview mode', () => {
    describe('WHEN rendered with addOns pricing type and resolved entities', () => {
      it('THEN should render the OneOffAddOnsPreviewTable', () => {
        renderPricingBlockView({
          mode: 'preview',
          attrs: { pricingType: 'addOns', entityIds: ['addon-1'] },
          entities: {
            'addon-1': {
              entityId: 'addon-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
              units: '2',
              totalAmount: '10000',
            },
          },
        })

        expect(screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should not render the edit mode click-to-edit block', () => {
        renderPricingBlockView({
          mode: 'preview',
          attrs: { pricingType: 'addOns', entityIds: ['addon-1'] },
          entities: {
            'addon-1': {
              entityId: 'addon-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
        })

        expect(screen.queryByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN rendered with plan pricing type and a resolved plan with data', () => {
      it('THEN should render the subscription plan preview table', () => {
        const planEntity: EntityData = {
          entityId: 'plan-1',
          entityType: 'plan',
          name: 'My Plan',
          code: 'plan_code',
          plan: {
            rows: [
              {
                kind: 'main' as const,
                rowType: 'usageCharge' as const,
                name: 'API calls',
                interval: PlanInterval.Monthly,
                timing: 'endOfPeriod' as const,
                units: { type: 'usageBased' as const },
                price: { type: 'variesWithUsage' as const },
              },
            ],
          },
        }

        renderPricingBlockView({
          mode: 'preview',
          entities: { 'plan-1': planEntity },
          attrs: { pricingType: 'plan', entityIds: ['plan-1'], localEntityIds: [] },
        })

        expect(screen.getByTestId(SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
        expect(screen.getByText('API calls')).toBeInTheDocument()
      })
    })

    describe('WHEN rendered with plan pricing type but no resolved plan', () => {
      it('THEN should render nothing (no Select-pricing button)', () => {
        renderPricingBlockView({
          mode: 'preview',
          entities: {},
          attrs: { pricingType: 'plan', entityIds: ['missing'], localEntityIds: [] },
        })

        expect(screen.queryByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)).not.toBeInTheDocument()
        // Preview mode must never fall through to the edit-mode interactive UI
        expect(screen.queryByTestId(SLASH_COMMAND_BLOCK_VIEW_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN rendered with addOns pricing type but no resolved entities', () => {
      it('THEN should render nothing (no unresolved view) in preview mode', () => {
        renderPricingBlockView({
          mode: 'preview',
          attrs: { pricingType: 'addOns', entityIds: ['addon-missing'] },
          entities: {},
        })

        expect(screen.queryByTestId(PRICING_BLOCK_VIEW_UNRESOLVED_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN rendered with empty entityIds', () => {
      it('THEN should not show the empty state button in preview mode', () => {
        renderPricingBlockView({
          mode: 'preview',
          attrs: { pricingType: 'addOns', entityIds: [] },
        })

        expect(screen.queryByTestId(PRICING_BLOCK_VIEW_EMPTY_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN customerCurrency is provided', () => {
      it('THEN should render the preview table using that currency', () => {
        renderPricingBlockView({
          mode: 'preview',
          attrs: { pricingType: 'addOns', entityIds: ['addon-1'] },
          entities: {
            'addon-1': {
              entityId: 'addon-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
              totalAmount: '100',
            },
          },
          customerCurrency: CurrencyEnum.Eur,
        })

        expect(screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
