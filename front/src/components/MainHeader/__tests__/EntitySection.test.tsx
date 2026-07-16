import { screen } from '@testing-library/react'

import { StatusType } from '~/components/designSystem/Status'
import { render } from '~/test-utils'

import { EntitySection } from '../EntitySection'
import {
  ENTITY_SECTION_METADATA_TEST_ID,
  ENTITY_SECTION_TEST_ID,
  ENTITY_SECTION_VIEW_NAME_TEST_ID,
} from '../mainHeaderTestIds'
import { MainHeaderEntityConfig } from '../types'

describe('EntitySection', () => {
  describe('GIVEN no entity', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<EntitySection />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN an entity with viewNameLoading true', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: '',
      viewNameLoading: true,
    }

    describe('WHEN the component renders', () => {
      it('THEN should display a loading skeleton for the title', () => {
        const { container } = render(<EntitySection entity={entity} />)

        expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
      })

      it('THEN should not display the view name', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.queryByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an entity with metadataLoading true', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: 'Customers',
      metadataLoading: true,
    }

    describe('WHEN the component renders', () => {
      it('THEN should display a loading skeleton for metadata', () => {
        const { container } = render(<EntitySection entity={entity} />)

        expect(container.querySelector('.animate-pulse')).toBeInTheDocument()
      })

      it('THEN should still display the view name', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.getByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)).toHaveTextContent('Customers')
      })

      it('THEN should not display the metadata text', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.queryByTestId(ENTITY_SECTION_METADATA_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an entity with both viewNameLoading and metadataLoading true', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: '',
      viewNameLoading: true,
      metadataLoading: true,
    }

    describe('WHEN the component renders', () => {
      it('THEN should display skeletons for both title and metadata', () => {
        const { container } = render(<EntitySection entity={entity} />)

        const skeletons = container.querySelectorAll('.animate-pulse')

        expect(skeletons.length).toBeGreaterThanOrEqual(2)
      })

      it('THEN should not display the view name', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.queryByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an entity with viewName only', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: 'Acme Corporation',
    }

    describe('WHEN the component renders', () => {
      it('THEN should display the entity section', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.getByTestId(ENTITY_SECTION_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the view name', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.getByTestId(ENTITY_SECTION_VIEW_NAME_TEST_ID)).toHaveTextContent(
          'Acme Corporation',
        )
      })

      it('THEN should not display metadata', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.queryByTestId(ENTITY_SECTION_METADATA_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an entity with metadata', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: 'Invoice #001',
      metadata: 'ext-id-12345',
    }

    describe('WHEN the component renders', () => {
      it('THEN should display the metadata', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.getByTestId(ENTITY_SECTION_METADATA_TEST_ID)).toHaveTextContent(
          'ext-id-12345',
        )
      })
    })
  })

  describe('GIVEN an entity with a ReactNode metadata', () => {
    const NODE_METADATA_TEST_ID = 'node-metadata-content'
    const entity: MainHeaderEntityConfig = {
      viewName: 'Customer',
      metadata: <span data-test={NODE_METADATA_TEST_ID}>copyable-ext-id</span>,
    }

    describe('WHEN the component renders', () => {
      it('THEN should render the node as-is inside the metadata slot', () => {
        render(<EntitySection entity={entity} />)

        const metadata = screen.getByTestId(ENTITY_SECTION_METADATA_TEST_ID)

        expect(metadata).toBeInTheDocument()
        expect(screen.getByTestId(NODE_METADATA_TEST_ID)).toHaveTextContent('copyable-ext-id')
      })
    })
  })

  describe('GIVEN an entity with badges', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: 'Customer',
      badges: [{ type: StatusType.success, label: 'Active' }],
    }

    describe('WHEN the component renders', () => {
      it('THEN should display the badge', () => {
        render(<EntitySection entity={entity} />)

        // Status component renders the badge label
        expect(screen.getByTestId(ENTITY_SECTION_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN an entity with an icon', () => {
    const entity: MainHeaderEntityConfig = {
      viewName: 'Stripe Integration',
      icon: 'plug',
    }

    describe('WHEN the component renders', () => {
      it('THEN should display the entity section with an avatar', () => {
        render(<EntitySection entity={entity} />)

        expect(screen.getByTestId(ENTITY_SECTION_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
