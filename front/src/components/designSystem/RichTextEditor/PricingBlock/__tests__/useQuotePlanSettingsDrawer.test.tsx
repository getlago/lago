import { act, renderHook, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import {
  PLAN_SETTINGS_DRAWER_SAVE_TEST_ID,
  useQuotePlanSettingsDrawer,
} from '../useQuotePlanSettingsDrawer'

const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({ open: mockDrawerOpen, close: mockDrawerClose }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

let mockPlanForm: Parameters<typeof useQuotePlanSettingsDrawer>[0]

describe('useQuotePlanSettingsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockPlanForm = createMockPlanForm()
  })

  describe('GIVEN the hook is rendered', () => {
    describe('WHEN initialized', () => {
      it('THEN should return an openDrawer function', () => {
        const { result } = renderHook(() => useQuotePlanSettingsDrawer(mockPlanForm))

        expect(result.current).toHaveProperty('openDrawer')
        expect(typeof result.current.openDrawer).toBe('function')
      })
    })
  })

  describe('GIVEN the drawer is closed', () => {
    describe('WHEN openDrawer is called', () => {
      it('THEN should open the drawer with title, children, and actions', () => {
        const { result } = renderHook(() => useQuotePlanSettingsDrawer(mockPlanForm))

        act(() => {
          result.current.openDrawer()
        })

        expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
        expect(mockDrawerOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            children: expect.anything(),
            actions: expect.anything(),
          }),
        )
      })
    })
  })

  describe('GIVEN the drawer actions are rendered', () => {
    describe('WHEN the cancel button is clicked', () => {
      it('THEN should restore the form to its values on open and close the drawer', async () => {
        const user = userEvent.setup()

        mockPlanForm = createMockPlanForm({ name: 'Original name' })

        const { result } = renderHook(() => useQuotePlanSettingsDrawer(mockPlanForm))

        act(() => {
          result.current.openDrawer()
        })

        const { actions } = mockDrawerOpen.mock.calls[0][0]

        render(actions)

        const cancelButton = screen.getAllByRole('button')[0]

        await user.click(cancelButton)

        // Cancel discards the drawer's edits by resetting to the snapshot taken on open
        expect(mockPlanForm.reset).toHaveBeenCalledWith(
          expect.objectContaining({ name: 'Original name' }),
          { keepDefaultValues: true },
        )
        expect(mockDrawerClose).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN the save button is clicked', () => {
      it('THEN should keep the live form changes and close the drawer', async () => {
        const user = userEvent.setup()
        const { result } = renderHook(() => useQuotePlanSettingsDrawer(mockPlanForm))

        act(() => {
          result.current.openDrawer()
        })

        const { actions } = mockDrawerOpen.mock.calls[0][0]

        render(actions)

        const saveButton = screen.getByTestId(PLAN_SETTINGS_DRAWER_SAVE_TEST_ID)

        await user.click(saveButton)

        // Save keeps the live edits (no reset) and just closes
        expect(mockPlanForm.reset).not.toHaveBeenCalled()
        expect(mockDrawerClose).toHaveBeenCalledTimes(1)
      })
    })
  })
})
