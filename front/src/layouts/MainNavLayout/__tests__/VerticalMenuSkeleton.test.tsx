import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  VERTICAL_MENU_SKELETON_ITEM_TEST_ID,
  VERTICAL_MENU_SKELETON_TEST_ID,
  VerticalMenuSkeleton,
} from '../VerticalMenuSkeleton'

describe('VerticalMenuSkeleton', () => {
  describe('Test ID constants', () => {
    it('exports expected test ID constants', () => {
      expect(VERTICAL_MENU_SKELETON_TEST_ID).toBe('vertical-menu-skeleton')
      expect(VERTICAL_MENU_SKELETON_ITEM_TEST_ID).toBe('vertical-menu-skeleton-item')
    })

    it('test ID constants follow kebab-case naming convention', () => {
      const testIds = [VERTICAL_MENU_SKELETON_TEST_ID, VERTICAL_MENU_SKELETON_ITEM_TEST_ID]

      testIds.forEach((testId) => {
        expect(testId).toMatch(/^[a-z-]+$/)
      })
    })
  })

  describe('Component rendering', () => {
    it('renders the skeleton container', () => {
      render(<VerticalMenuSkeleton numberOfElements={3} />)

      expect(screen.getByTestId(VERTICAL_MENU_SKELETON_TEST_ID)).toBeInTheDocument()
    })

    it('renders the correct number of skeleton items', () => {
      render(<VerticalMenuSkeleton numberOfElements={5} />)

      const skeletonItems = screen.getAllByTestId(VERTICAL_MENU_SKELETON_ITEM_TEST_ID)

      expect(skeletonItems).toHaveLength(5)
    })

    it('renders no items when numberOfElements is 0', () => {
      render(<VerticalMenuSkeleton numberOfElements={0} />)

      const skeletonItems = screen.queryAllByTestId(VERTICAL_MENU_SKELETON_ITEM_TEST_ID)

      expect(skeletonItems).toHaveLength(0)
    })

    it('renders single item when numberOfElements is 1', () => {
      render(<VerticalMenuSkeleton numberOfElements={1} />)

      const skeletonItems = screen.getAllByTestId(VERTICAL_MENU_SKELETON_ITEM_TEST_ID)

      expect(skeletonItems).toHaveLength(1)
    })
  })
})
