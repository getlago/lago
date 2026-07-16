import HelperText from '~/pages/createCustomers/customerInformation/HelperText'
import { render } from '~/test-utils'

describe('HelperText Integration Tests', () => {
  describe('WHEN rendering the component', () => {
    it('THEN should render without crashing', () => {
      const { container } = render(<HelperText billingEntityCode="TEST_CODE" />)

      // Check for accordion content by checking that the component rendered
      expect(container.firstChild).toBeInTheDocument()
    })

    it('THEN should render a matching snapshot', () => {
      const rendered = render(<HelperText billingEntityCode="TEST_CODE" />)

      expect(rendered.container).toMatchSnapshot()
    })
  })
})
