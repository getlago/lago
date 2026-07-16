import { render } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { getCleanKey, Shortcut, useShortcuts } from '~/hooks/ui/useShortcuts'

const MyTestComponentThatUsesShortcuts = ({ shortcuts }: { shortcuts: Shortcut[] }) => {
  useShortcuts(shortcuts)

  return null
}

describe('useShortcuts()', () => {
  describe('when Cmd D shortcut is enabled and Cmd+D is pressed', () => {
    const action = jest.fn()
    const shortcuts: Shortcut[] = [
      {
        action,
        keys: ['Cmd', 'KeyD'],
        disabled: false,
      },
    ]

    it('calls the action callback', async () => {
      render(
        <div>
          <MyTestComponentThatUsesShortcuts shortcuts={shortcuts} />
        </div>,
      )

      // cf: https://testing-library.com/docs/ecosystem-user-event#keyboardtext-options
      await userEvent.keyboard('{Meta>}D')

      expect(action).toHaveBeenCalled()
    })
  })

  describe('when Cmd D shortcut is DISABLED and Cmd+D is pressed', () => {
    const action = jest.fn()
    const shortcuts: Shortcut[] = [
      {
        action,
        keys: ['Cmd', 'KeyD'],
        disabled: true,
      },
    ]

    it('does not call the action callback', async () => {
      render(
        <div>
          <MyTestComponentThatUsesShortcuts shortcuts={shortcuts} />
        </div>,
      )

      await userEvent.keyboard('{Meta>}D')

      expect(action).not.toHaveBeenCalled()
    })
  })

  describe('when Cmd Enter shortcut is enabled and Cmd+Enter is pressed', () => {
    const action = jest.fn()
    const shortcuts: Shortcut[] = [
      {
        action,
        keys: ['Cmd', 'Enter'],
        disabled: false,
      },
    ]

    it('works.', async () => {
      render(
        <div>
          <MyTestComponentThatUsesShortcuts shortcuts={shortcuts} />
        </div>,
      )

      await userEvent.keyboard('{Meta>}[Enter]')

      expect(action).toHaveBeenCalled()
    })
  })

  describe('when additionnal keys are pressed', () => {
    const action = jest.fn()
    const shortcuts: Shortcut[] = [
      {
        action,
        keys: ['Cmd', 'KeyD'],
        disabled: false,
      },
    ]

    it('should not fire the action', async () => {
      render(
        <div>
          <MyTestComponentThatUsesShortcuts shortcuts={shortcuts} />
        </div>,
      )

      // cf: https://testing-library.com/docs/ecosystem-user-event#keyboardtext-options
      await userEvent.keyboard('{Meta>}{I>}{D}')

      expect(action).not.toHaveBeenCalled()
    })
  })

  describe('getCleanKey()', () => {
    it('should clean keys correctly', () => {
      expect(getCleanKey('MetaLeft')).toEqual('Cmd')
      expect(getCleanKey('MetaRight')).toEqual('Cmd')
      expect(getCleanKey('AltLeft')).toEqual('Alt')
      expect(getCleanKey('AltRight')).toEqual('Alt')
      expect(getCleanKey('ControlLeft')).toEqual('Ctrl')
      expect(getCleanKey('ControlRight')).toEqual('Ctrl')
    })
  })
})
