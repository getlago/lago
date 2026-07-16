import { screen } from '@testing-library/react'
import React from 'react'

import { render } from '~/test-utils'

import { BREADCRUMB_NAV_TEST_ID } from '../Breadcrumb'
import { MainHeader } from '../MainHeader'
import {
  ACTIONS_BLOCK_TEST_ID,
  ENTITY_SECTION_METADATA_TEST_ID,
  ENTITY_SECTION_TEST_ID,
  ENTITY_SECTION_VIEW_NAME_TEST_ID,
  MAIN_HEADER_FILTERS_TEST_ID,
  MAIN_HEADER_TEST_ID,
} from '../mainHeaderTestIds'
import { MainHeaderConfig } from '../types'

const mockUseMainHeaderReader = jest.fn()

jest.mock('../MainHeaderContext', () => ({
  ...jest.requireActual('../MainHeaderContext'),
  useMainHeaderReader: () => mockUseMainHeaderReader(),
}))

describe('MainHeader', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no config is set', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render nothing', () => {
        mockUseMainHeaderReader.mockReturnValue({ config: null })

        const { container } = render(<MainHeader />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN a config with breadcrumb', () => {
    const config: MainHeaderConfig = {
      breadcrumb: [
        { label: 'Customers', path: '/customers' },
        { label: 'Acme Corp', path: '/customers/1' },
      ],
      entity: { viewName: 'Acme Corp' },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the breadcrumb nav', () => {
        render(<MainHeader />)

        const breadcrumbs = screen.getAllByTestId(BREADCRUMB_NAV_TEST_ID)

        expect(breadcrumbs.length).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN a config with entity', () => {
    const config: MainHeaderConfig = {
      entity: { viewName: 'Test Entity' },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the entity view name', () => {
        render(<MainHeader />)

        const viewNames = screen.getAllByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)

        expect(viewNames.length).toBeGreaterThanOrEqual(1)
        expect(viewNames[0]).toHaveTextContent('Test Entity')
      })
    })
  })

  describe('GIVEN a config with actions', () => {
    const config: MainHeaderConfig = {
      actions: {
        items: [{ type: 'action', label: 'Save', onClick: jest.fn(), dataTest: 'save-action' }],
      },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the actions block', () => {
        render(<MainHeader />)

        expect(screen.getByTestId(ACTIONS_BLOCK_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a config with tabs', () => {
    describe('WHEN there are fewer than 2 tabs', () => {
      it('THEN should not render the tab bar', () => {
        const config: MainHeaderConfig = {
          tabs: [
            {
              title: 'Only Tab',
              link: '/only',
              content: React.createElement('div', null, 'content'),
            },
          ],
        }

        mockUseMainHeaderReader.mockReturnValue({ config })
        render(<MainHeader />)

        expect(screen.queryByRole('navigation')).not.toBeInTheDocument()
      })
    })

    describe('WHEN there are 2 or more tabs', () => {
      it('THEN should render the tab bar', () => {
        const config: MainHeaderConfig = {
          tabs: [
            {
              title: 'Overview',
              link: '/overview',
              content: React.createElement('div', null, 'Overview'),
            },
            {
              title: 'Details',
              link: '/details',
              content: React.createElement('div', null, 'Details'),
            },
          ],
        }

        mockUseMainHeaderReader.mockReturnValue({ config })
        render(<MainHeader />)

        expect(screen.getAllByRole('tab')).toHaveLength(2)
      })
    })
  })

  describe('GIVEN a config with filtersSection', () => {
    const config: MainHeaderConfig = {
      filtersSection: React.createElement('div', { 'data-test': 'custom-filter' }, 'Filters'),
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the filters section', () => {
        render(<MainHeader />)

        expect(screen.getByTestId(MAIN_HEADER_FILTERS_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId('custom-filter')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a config with entity metadata', () => {
    const config: MainHeaderConfig = {
      entity: {
        viewName: 'Acme Corp',
        metadata: 'acme-corp-code',
      },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the entity metadata', () => {
        render(<MainHeader />)

        const metadataElements = screen.getAllByTestId(ENTITY_SECTION_METADATA_TEST_ID)

        expect(metadataElements.length).toBeGreaterThanOrEqual(1)
        expect(metadataElements[0]).toHaveTextContent('acme-corp-code')
      })
    })
  })

  describe('GIVEN a config with entity badges', () => {
    const config: MainHeaderConfig = {
      entity: {
        viewName: 'Integration X',
        badges: [{ type: 'success', label: 'Connected' }],
      },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the entity section with badges', () => {
        render(<MainHeader />)

        const entitySections = screen.getAllByTestId(ENTITY_SECTION_TEST_ID)

        expect(entitySections.length).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN a config with entity icon', () => {
    const config: MainHeaderConfig = {
      entity: {
        viewName: 'Stripe',
        icon: 'plug',
      },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should display the entity section', () => {
        render(<MainHeader />)

        const entitySections = screen.getAllByTestId(ENTITY_SECTION_TEST_ID)

        expect(entitySections.length).toBeGreaterThanOrEqual(1)
        expect(entitySections[0]).toHaveTextContent('Stripe')
      })
    })
  })

  describe('GIVEN a config with entity loading flags', () => {
    const config: MainHeaderConfig = {
      entity: { viewName: '', viewNameLoading: true },
      actions: { items: [], loading: true },
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should render the header element', () => {
        render(<MainHeader />)

        expect(screen.getByTestId(MAIN_HEADER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should not display the entity view name', () => {
        render(<MainHeader />)

        expect(screen.queryByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a config without entity', () => {
    const config: MainHeaderConfig = {
      breadcrumb: [{ label: 'Settings', path: '/settings' }],
    }

    beforeEach(() => {
      mockUseMainHeaderReader.mockReturnValue({ config })
    })

    describe('WHEN the component renders', () => {
      it('THEN should not display the entity section', () => {
        render(<MainHeader />)

        expect(screen.queryByTestId(ENTITY_SECTION_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
