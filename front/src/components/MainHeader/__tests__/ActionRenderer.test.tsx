import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { ActionsBlock } from '../ActionRenderer'
import { ACTIONS_BLOCK_TEST_ID } from '../mainHeaderTestIds'
import { MainHeaderAction } from '../types'

describe('ActionsBlock', () => {
  describe('GIVEN loading is true', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not render the actions container', () => {
        const { container } = render(<ActionsBlock actions={{ items: [], loading: true }} />)

        expect(screen.queryByTestId(ACTIONS_BLOCK_TEST_ID)).not.toBeInTheDocument()
        // Skeleton should be rendered (an animate-pulse div)
        expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no actions are provided', () => {
    describe('WHEN actions is undefined', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<ActionsBlock />)

        expect(container.innerHTML).toBe('')
      })
    })

    describe('WHEN actions is an empty array', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<ActionsBlock actions={{ items: [] }} />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN actions of type "action" are provided', () => {
    const onClick = jest.fn()
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Edit',
        onClick,
        dataTest: 'edit-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should display the actions container', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId(ACTIONS_BLOCK_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the action button', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('edit-button')).toBeInTheDocument()
      })
    })

    describe('WHEN the action button is clicked', () => {
      it('THEN should call the onClick handler', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('edit-button'))

        expect(onClick).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('GIVEN an action with variant and startIcon', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Add',
        onClick: jest.fn(),
        variant: 'primary',
        startIcon: 'plus',
        dataTest: 'add-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render the button with the correct data-test', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('add-button')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a disabled action', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Disabled Action',
        onClick: jest.fn(),
        disabled: true,
        dataTest: 'disabled-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render a disabled button', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('disabled-button')).toBeDisabled()
      })
    })
  })

  describe('GIVEN a dropdown action', () => {
    const onItemClick = jest.fn()
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'More actions',
        dataTest: 'dropdown-trigger',
        items: [
          {
            label: 'Delete',
            onClick: onItemClick,
            danger: true,
            dataTest: 'delete-item',
          },
          {
            label: 'Hidden item',
            onClick: jest.fn(),
            hidden: true,
          },
        ],
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should display the dropdown trigger button', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('dropdown-trigger')).toBeInTheDocument()
      })
    })

    describe('WHEN the dropdown trigger is clicked', () => {
      it('THEN should show visible items and hide hidden items', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('dropdown-trigger'))

        expect(screen.getByTestId('delete-item')).toBeInTheDocument()
        expect(screen.queryByText('Hidden item')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a hidden top-level action', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Visible',
        onClick: jest.fn(),
        dataTest: 'visible-button',
      },
      {
        type: 'action',
        label: 'Hidden',
        onClick: jest.fn(),
        hidden: true,
        dataTest: 'hidden-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should display the visible action and hide the hidden one', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('visible-button')).toBeInTheDocument()
        expect(screen.queryByTestId('hidden-button')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN all top-level actions are hidden', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Hidden 1',
        onClick: jest.fn(),
        hidden: true,
      },
      {
        type: 'action',
        label: 'Hidden 2',
        onClick: jest.fn(),
        hidden: true,
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<ActionsBlock actions={{ items: actions }} />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN a dropdown where all items are hidden', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'Empty Dropdown',
        items: [
          { label: 'Hidden 1', onClick: jest.fn(), hidden: true },
          { label: 'Hidden 2', onClick: jest.fn(), hidden: true },
        ],
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<ActionsBlock actions={{ items: actions }} />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN multiple actions of different types', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Save',
        onClick: jest.fn(),
        dataTest: 'save-button',
      },
      {
        type: 'action',
        label: 'Cancel',
        onClick: jest.fn(),
        variant: 'quaternary',
        dataTest: 'cancel-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it.each([
        ['save button', 'save-button'],
        ['cancel button', 'cancel-button'],
      ])('THEN should display the %s', (_, testId) => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an action with endIcon', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'action',
        label: 'Premium Action',
        onClick: jest.fn(),
        endIcon: 'sparkles',
        dataTest: 'premium-button',
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render the button with the correct data-test', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('premium-button')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a dropdown item with startIcon', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'Actions',
        dataTest: 'dropdown-starticon',
        items: [
          {
            label: 'Add item',
            onClick: jest.fn(),
            startIcon: 'plus',
            dataTest: 'add-item',
          },
        ],
      },
    ]

    describe('WHEN the dropdown is opened', () => {
      it('THEN should display the dropdown item', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('dropdown-starticon'))

        expect(screen.getByTestId('add-item')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a dropdown item with endIcon', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'Actions',
        dataTest: 'dropdown-endicon',
        items: [
          {
            label: 'Premium item',
            onClick: jest.fn(),
            endIcon: 'sparkles',
            dataTest: 'premium-item',
          },
        ],
      },
    ]

    describe('WHEN the dropdown is opened', () => {
      it('THEN should display the dropdown item', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('dropdown-endicon'))

        expect(screen.getByTestId('premium-item')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a custom action', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'custom',
        label: 'Custom Action',
        content: <div data-test="custom-content">Custom rendered content</div>,
      },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render the custom content', () => {
        render(<ActionsBlock actions={{ items: actions }} />)

        expect(screen.getByTestId('custom-content')).toBeInTheDocument()
        expect(screen.getByText('Custom rendered content')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a dropdown item with tooltip', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'Actions',
        dataTest: 'dropdown-tooltip',
        items: [
          {
            label: 'Disabled item',
            onClick: jest.fn(),
            disabled: true,
            tooltip: 'This action is not available',
            dataTest: 'tooltip-item',
          },
        ],
      },
    ]

    describe('WHEN the dropdown is opened', () => {
      it('THEN should display the disabled dropdown item', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('dropdown-tooltip'))

        expect(screen.getByTestId('tooltip-item')).toBeInTheDocument()
        expect(screen.getByTestId('tooltip-item')).toBeDisabled()
      })
    })
  })

  describe('GIVEN a dropdown with mixed items (tooltip and no tooltip)', () => {
    const actions: MainHeaderAction[] = [
      {
        type: 'dropdown',
        label: 'Actions',
        dataTest: 'dropdown-mixed',
        items: [
          {
            label: 'Normal item',
            onClick: jest.fn(),
            dataTest: 'normal-item',
          },
          {
            label: 'Tooltip item',
            onClick: jest.fn(),
            tooltip: 'Some help text',
            dataTest: 'item-with-tooltip',
          },
        ],
      },
    ]

    describe('WHEN the dropdown is opened', () => {
      it('THEN should display both items', async () => {
        const user = userEvent.setup()

        render(<ActionsBlock actions={{ items: actions }} />)

        await user.click(screen.getByTestId('dropdown-mixed'))

        expect(screen.getByTestId('normal-item')).toBeInTheDocument()
        expect(screen.getByTestId('item-with-tooltip')).toBeInTheDocument()
      })
    })
  })
})
