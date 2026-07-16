import { render } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { useKeyNavigationOptions, useListKeysNavigation } from '~/hooks/ui/useListKeyNavigation'

interface PageWrapperProps {
  conponentProps: useKeyNavigationOptions
  children: ReactNode
}

const MyTestComponentThatUsesNavigation = ({ conponentProps, children }: PageWrapperProps) => {
  const { onKeyDown } = useListKeysNavigation(conponentProps)

  // eslint-disable-next-line jsx-a11y/no-static-element-interactions
  return <div onKeyDown={onKeyDown}>{children}</div>
}

describe('useListKeyNavigation()', () => {
  describe('disabled', () => {
    const action = jest.fn()
    const disabled = true

    it('does not return', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: action,
            navigate: action,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid*/}
          <a id="item-0">Active element</a>
          <a id="item-1">Next element</a>
          {/* eslint-enable jsx-a11y/anchor-is-valid*/}
        </MyTestComponentThatUsesNavigation>,
      )

      await userEvent.keyboard('{ArrowDown}')
      await userEvent.keyboard('{j}')
      await userEvent.keyboard('{ArrowUp}')
      await userEvent.keyboard('{k}')
      await userEvent.keyboard('{Enter}')

      expect(action).not.toHaveBeenCalled()
    })
  })

  describe('Pressing ArrowDown or j', () => {
    const navigate = jest.fn()
    const disabled = false

    it('focuses the next element', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: (i) => `item-${i}`,
            navigate: navigate,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
          <a tabIndex={0} id="item-0">
            First
          </a>
          <a tabIndex={0} id="item-1">
            Second
          </a>
          <a tabIndex={0} id="item-2">
            Third
          </a>

          {/* eslint-enable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
        </MyTestComponentThatUsesNavigation>,
      )

      document?.getElementById('item-0')?.focus()
      expect(document?.activeElement?.id).toEqual('item-0')

      await userEvent.keyboard('{ArrowDown}')
      expect(document?.activeElement?.id).toEqual('item-1')

      await userEvent.keyboard('{j}')
      expect(document?.activeElement?.id).toEqual('item-2')

      expect(navigate).not.toHaveBeenCalled()
    })

    it('returns if no next element to focus', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: (i) => `item-${i}`,
            navigate: navigate,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
          <a tabIndex={0} id="item-0">
            First
          </a>
          {/* eslint-enable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
        </MyTestComponentThatUsesNavigation>,
      )

      document?.getElementById('item-0')?.focus()
      expect(document?.activeElement?.id).toEqual('item-0')

      await userEvent.keyboard('{ArrowDown}')
      await userEvent.keyboard('{j}')

      expect(document?.activeElement?.id).toEqual('item-0')
      expect(navigate).not.toHaveBeenCalled()
    })
  })

  describe('Pressing ArrowUp or k', () => {
    const navigate = jest.fn()
    const disabled = false

    it('focuses the next element', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: (i) => `item-${i}`,
            navigate: navigate,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
          <a tabIndex={0} id="item-0">
            First
          </a>
          <a tabIndex={0} id="item-1">
            Second
          </a>
          <a tabIndex={0} id="item-2">
            Third
          </a>

          {/* eslint-enable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
        </MyTestComponentThatUsesNavigation>,
      )

      document?.getElementById('item-2')?.focus()
      expect(document?.activeElement?.id).toEqual('item-2')

      await userEvent.keyboard('{ArrowUp}')
      expect(document?.activeElement?.id).toEqual('item-1')

      await userEvent.keyboard('{k}')
      expect(document?.activeElement?.id).toEqual('item-0')

      expect(navigate).not.toHaveBeenCalled()
    })

    it('returns if no previous element to focus', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: (i) => `item-${i}`,
            navigate: navigate,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
          <a tabIndex={0} id="item-0">
            First
          </a>
          {/* eslint-enable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
        </MyTestComponentThatUsesNavigation>,
      )

      document?.getElementById('item-0')?.focus()
      expect(document?.activeElement?.id).toEqual('item-0')

      await userEvent.keyboard('{ArrowUp}')
      await userEvent.keyboard('{k}')

      expect(document?.activeElement?.id).toEqual('item-0')
      expect(navigate).not.toHaveBeenCalled()
    })
  })

  describe('Pressing Enter on second element', () => {
    const navigate = jest.fn((id) => id)
    const disabled = false

    it('triggers navigate method with correct argument', async () => {
      render(
        <MyTestComponentThatUsesNavigation
          conponentProps={{
            getElmId: (i) => `item-${i}`,
            navigate: navigate,
            disabled: disabled,
          }}
        >
          {/* eslint-disable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
          <a tabIndex={0} id="item-0" data-id="model-id-0">
            First
          </a>
          <a tabIndex={0} id="item-1" data-id="model-id-1">
            Second
          </a>

          {/* eslint-enable jsx-a11y/anchor-is-valid, jsx-a11y/no-noninteractive-tabindex*/}
        </MyTestComponentThatUsesNavigation>,
      )

      document?.getElementById('item-0')?.focus()
      expect(document?.activeElement?.id).toEqual('item-0')

      await userEvent.keyboard('{j}')
      expect(document?.activeElement?.id).toEqual('item-1')

      await userEvent.keyboard('{Enter}')
      expect(document?.activeElement?.id).toEqual('item-1')
      expect(navigate).toHaveBeenCalled()
      expect(navigate.mock.results[0].value).toBe('model-id-1')
    })
  })
})
