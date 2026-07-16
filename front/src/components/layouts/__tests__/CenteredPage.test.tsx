import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  CenteredPage,
  PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID,
  PAGE_SECTION_TITLE_TEST_ID,
  SUBSECTION_TITLE_DESCRIPTION_TEST_ID,
  SUBSECTION_TITLE_TEST_ID,
} from '../CenteredPage'

describe('CenteredPage', () => {
  describe('PageSectionTitle', () => {
    describe('GIVEN a PageSectionTitle with only a title', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(<CenteredPage.PageSectionTitle title="My Section" />)

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the title text', () => {
          render(<CenteredPage.PageSectionTitle title="My Section" />)

          const container = screen.getByTestId(PAGE_SECTION_TITLE_TEST_ID)

          expect(container).toBeInTheDocument()
          expect(container).toHaveTextContent('My Section')
        })

        it('THEN should not render the description', () => {
          render(<CenteredPage.PageSectionTitle title="My Section" />)

          const description = screen.queryByTestId(PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(description).not.toBeInTheDocument()
        })
      })
    })

    describe('GIVEN a PageSectionTitle with a string description', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(
            <CenteredPage.PageSectionTitle
              title="My Section"
              description="Some description text"
            />,
          )

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the description text', () => {
          render(
            <CenteredPage.PageSectionTitle
              title="My Section"
              description="Some description text"
            />,
          )

          const description = screen.getByTestId(PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(description).toBeInTheDocument()
          expect(description).toHaveTextContent('Some description text')
        })
      })
    })

    describe('GIVEN a PageSectionTitle with a JSX description', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(
            <CenteredPage.PageSectionTitle
              title="My Section"
              description={<span data-test="custom-jsx-desc">Custom JSX</span>}
            />,
          )

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the JSX element directly', () => {
          render(
            <CenteredPage.PageSectionTitle
              title="My Section"
              description={<span data-test="custom-jsx-desc">Custom JSX</span>}
            />,
          )

          const customJsx = screen.getByTestId('custom-jsx-desc')

          expect(customJsx).toBeInTheDocument()
          expect(customJsx).toHaveTextContent('Custom JSX')
        })

        it('THEN should not render the string description wrapper', () => {
          render(
            <CenteredPage.PageSectionTitle
              title="My Section"
              description={<span data-test="custom-jsx-desc">Custom JSX</span>}
            />,
          )

          const stringDescription = screen.queryByTestId(PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(stringDescription).not.toBeInTheDocument()
        })
      })
    })
  })

  describe('SubsectionTitle', () => {
    describe('GIVEN a SubsectionTitle with only a title', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(<CenteredPage.SubsectionTitle title="My Subsection" />)

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the title text', () => {
          render(<CenteredPage.SubsectionTitle title="My Subsection" />)

          const container = screen.getByTestId(SUBSECTION_TITLE_TEST_ID)

          expect(container).toBeInTheDocument()
          expect(container).toHaveTextContent('My Subsection')
        })

        it('THEN should not render the description', () => {
          render(<CenteredPage.SubsectionTitle title="My Subsection" />)

          const description = screen.queryByTestId(SUBSECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(description).not.toBeInTheDocument()
        })
      })
    })

    describe('GIVEN a SubsectionTitle with a string description', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(
            <CenteredPage.SubsectionTitle
              title="My Subsection"
              description="Subsection description"
            />,
          )

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the description text', () => {
          render(
            <CenteredPage.SubsectionTitle
              title="My Subsection"
              description="Subsection description"
            />,
          )

          const description = screen.getByTestId(SUBSECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(description).toBeInTheDocument()
          expect(description).toHaveTextContent('Subsection description')
        })
      })
    })

    describe('GIVEN a SubsectionTitle with a JSX description', () => {
      describe('WHEN it is rendered', () => {
        it('THEN should match snapshot', () => {
          const { container } = render(
            <CenteredPage.SubsectionTitle
              title="My Subsection"
              description={<div data-test="custom-subsection-desc">Custom element</div>}
            />,
          )

          expect(container).toMatchSnapshot()
        })

        it('THEN should render the JSX element directly', () => {
          render(
            <CenteredPage.SubsectionTitle
              title="My Subsection"
              description={<div data-test="custom-subsection-desc">Custom element</div>}
            />,
          )

          const customJsx = screen.getByTestId('custom-subsection-desc')

          expect(customJsx).toBeInTheDocument()
          expect(customJsx).toHaveTextContent('Custom element')
        })

        it('THEN should not render the string description wrapper', () => {
          render(
            <CenteredPage.SubsectionTitle
              title="My Subsection"
              description={<div data-test="custom-subsection-desc">Custom element</div>}
            />,
          )

          const stringDescription = screen.queryByTestId(SUBSECTION_TITLE_DESCRIPTION_TEST_ID)

          expect(stringDescription).not.toBeInTheDocument()
        })
      })
    })
  })
})
