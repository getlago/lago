import { ExternalAppsAccordionLayout } from '~/pages/createCustomers/externalAppsAccordion/common/ExternalAppsAccordionLayout'
import { render } from '~/test-utils'

describe('ExternalAppsAccordionLayout Integration Tests', () => {
  describe('WHEN rendering the Summary component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<ExternalAppsAccordionLayout.Summary />)

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<ExternalAppsAccordionLayout.Summary />)

      expect(rendered.container).toMatchSnapshot()
    })

    it('THEN should render a matching snapshot in loading state', () => {
      const rendered = render(<ExternalAppsAccordionLayout.Summary loading={true} />)

      expect(rendered.container).toMatchSnapshot()
    })
  })

  describe('WHEN rendering the Summary component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(
        <ExternalAppsAccordionLayout.ComboboxItem label="label" subLabel="subLabel" />,
      )

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(
        <ExternalAppsAccordionLayout.ComboboxItem label="label" subLabel="subLabel" />,
      )

      expect(rendered.container).toMatchSnapshot()
    })
  })
})
