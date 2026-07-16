import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import QuoteDetailsActivityLogs, {
  QUOTE_ACTIVITY_LOGS_CONTAINER_TEST_ID,
} from '../QuoteDetailsActivityLogs'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('QuoteDetailsActivityLogs', () => {
  describe('GIVEN the component is rendered', () => {
    it('THEN should render the container', () => {
      render(<QuoteDetailsActivityLogs />)

      expect(screen.getByTestId(QUOTE_ACTIVITY_LOGS_CONTAINER_TEST_ID)).toBeInTheDocument()
    })

    it('THEN should render the placeholder inside the container', () => {
      render(<QuoteDetailsActivityLogs />)

      const container = screen.getByTestId(QUOTE_ACTIVITY_LOGS_CONTAINER_TEST_ID)

      expect(container.childNodes.length).toBeGreaterThanOrEqual(1)
    })
  })
})
