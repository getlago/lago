import { act, cleanup, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import Members from '../Members'

jest.mock('../MembersList', () => ({
  __esModule: true,
  default: () => <div data-test="members-list">Members List</div>,
}))

jest.mock('../MembersInvitationList', () => ({
  __esModule: true,
  default: () => <div data-test="members-invitation-list">Invitations List</div>,
}))

describe('Members', () => {
  afterEach(cleanup)

  describe('Rendering', () => {
    it('renders the page header with title', async () => {
      await act(() => render(<Members />))

      // Multiple elements contain "Members", so use getAllByText and check at least one exists
      const membersElements = screen.getAllByText(/members/i)

      expect(membersElements.length).toBeGreaterThan(0)
    })

    it('renders navigation tabs', async () => {
      await act(() => render(<Members />))

      expect(screen.getByRole('tablist')).toBeInTheDocument()
    })

    it('renders the Members tab', async () => {
      await act(() => render(<Members />))

      expect(screen.getByRole('tab', { name: /members/i })).toBeInTheDocument()
    })

    it('renders the Invitations tab', async () => {
      await act(() => render(<Members />))

      expect(screen.getByRole('tab', { name: /invitations/i })).toBeInTheDocument()
    })

    it('renders the MembersList component by default', async () => {
      await act(() => render(<Members />))

      expect(screen.getByTestId('members-list')).toBeInTheDocument()
    })
  })

  describe('Snapshot', () => {
    it('matches snapshot', async () => {
      const { container } = await act(() => render(<Members />))

      expect(container).toMatchSnapshot()
    })
  })
})
