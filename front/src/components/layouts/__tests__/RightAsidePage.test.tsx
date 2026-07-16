import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  RIGHT_ASIDE_PAGE_HEADER_DIVIDER_TEST_ID,
  RIGHT_ASIDE_PAGE_HEADER_TEST_ID,
  RightAsidePage,
} from '../RightAsidePage'

// The design system Button hardcodes data-test="button", so we find
// the close button via the header's last [data-test="button"] element.
const getCloseButton = () => {
  const header = screen.getByTestId(RIGHT_ASIDE_PAGE_HEADER_TEST_ID)
  const buttons = header.querySelectorAll('[data-test="button"]')

  return buttons[buttons.length - 1] as HTMLButtonElement
}

describe('RightAsidePage', () => {
  describe('Header', () => {
    describe('GIVEN a Header with a title', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should render the title text', () => {
          render(<RightAsidePage.Header title={<span>My Title</span>} onClose={jest.fn()} />)

          const header = screen.getByTestId(RIGHT_ASIDE_PAGE_HEADER_TEST_ID)

          expect(header).toBeInTheDocument()
          expect(header).toHaveTextContent('My Title')
        })
      })
    })

    describe('GIVEN a Header with an onClose handler', () => {
      describe('WHEN the close button is clicked', () => {
        it('THEN should call onClose', async () => {
          const user = userEvent.setup()
          const onClose = jest.fn()

          render(<RightAsidePage.Header title={<span>Title</span>} onClose={onClose} />)

          await user.click(getCloseButton())

          expect(onClose).toHaveBeenCalledTimes(1)
        })
      })
    })

    describe('GIVEN a Header with children', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should show the divider', () => {
          render(
            <RightAsidePage.Header title={<span>Title</span>} onClose={jest.fn()}>
              <button>Action</button>
            </RightAsidePage.Header>,
          )

          expect(screen.getByTestId(RIGHT_ASIDE_PAGE_HEADER_DIVIDER_TEST_ID)).toBeInTheDocument()
        })
      })
    })

    describe('GIVEN a Header without children', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should not show the divider', () => {
          render(<RightAsidePage.Header title={<span>Title</span>} onClose={jest.fn()} />)

          expect(
            screen.queryByTestId(RIGHT_ASIDE_PAGE_HEADER_DIVIDER_TEST_ID),
          ).not.toBeInTheDocument()
        })
      })
    })

    describe('GIVEN a Header with isCloseButtonDisabled set to true', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should disable the close button', () => {
          render(
            <RightAsidePage.Header
              title={<span>Title</span>}
              onClose={jest.fn()}
              isCloseButtonDisabled
            />,
          )

          expect(getCloseButton()).toBeDisabled()
        })
      })
    })
  })

  describe('Content', () => {
    describe('GIVEN a Content with children and aside', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should render both children and aside', () => {
          render(
            <RightAsidePage.Content aside={<div data-test="aside-content">Aside</div>}>
              <div data-test="main-content">Main</div>
            </RightAsidePage.Content>,
          )

          expect(screen.getByTestId('main-content')).toHaveTextContent('Main')
          expect(screen.getByTestId('aside-content')).toHaveTextContent('Aside')
        })
      })
    })
  })

  describe('SubHeader', () => {
    describe('GIVEN a SubHeader with children', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should render the children', () => {
          render(
            <RightAsidePage.SubHeader>
              <span data-test="subheader-child">Sub Header Content</span>
            </RightAsidePage.SubHeader>,
          )

          expect(screen.getByTestId('subheader-child')).toHaveTextContent('Sub Header Content')
        })
      })
    })
  })
})
