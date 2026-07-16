import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { act, createRef } from 'react'
import { object, string } from 'yup'

import { MappableTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { IntegrationMapItemDrawer } from '../IntegrationMapItemDrawer'
import { IntegrationMapItemDrawerRef } from '../types'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type FormValues = Record<string, { selectedElementValue: string }>

const BILLING_ENTITIES = [
  { id: null, key: 'default', name: 'Default' },
  { id: 'be-1', key: 'be-1', name: 'Entity One' },
  { id: 'be-2', key: 'be-2', name: 'Entity Two' },
]

const ITEM_MAPPINGS = {
  default: {
    itemId: null,
    itemExternalId: null,
    lagoMappableId: 'mappable-1',
    lagoMappableName: 'Test Metric',
  },
  'be-1': {
    itemId: null,
    itemExternalId: null,
    lagoMappableId: 'mappable-1',
    lagoMappableName: 'Test Metric',
  },
  'be-2': {
    itemId: null,
    itemExternalId: null,
    lagoMappableId: 'mappable-1',
    lagoMappableName: 'Test Metric',
  },
}

const mockFormComponent = jest.fn(
  ({ billingEntityKey }: { formikProps: unknown; billingEntityKey: string }) => (
    <div data-test={`form-${billingEntityKey}`}>Form for {billingEntityKey}</div>
  ),
)

const mockHandleDataMutation = jest.fn().mockResolvedValue({ success: true })
const mockResetLocalData = jest.fn()

const prepare = async () => {
  const drawerRef = createRef<IntegrationMapItemDrawerRef>()

  const utils = render(
    <IntegrationMapItemDrawer<FormValues>
      type={MappableTypeEnum.BillableMetric}
      integrationId="integration-123"
      billingEntities={BILLING_ENTITIES}
      itemMappings={ITEM_MAPPINGS}
      title="Map Test Metric"
      description="Select the external account for this metric"
      validationSchema={object().shape({
        selectedElementValue: string(),
      })}
      drawerRef={drawerRef}
      formComponent={mockFormComponent}
      getFormInitialValues={() => ({
        default: { selectedElementValue: '' },
        'be-1': { selectedElementValue: '' },
        'be-2': { selectedElementValue: '' },
      })}
      validateForm={() => ({})}
      handleDataMutation={mockHandleDataMutation}
      resetLocalData={mockResetLocalData}
    />,
  )

  // Open the drawer so MUI renders the portal content
  await act(async () => {
    drawerRef.current?.openDrawer()
  })

  return { ...utils, drawerRef }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('IntegrationMapItemDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders the drawer with title and description', async () => {
    await prepare()

    // Title appears twice: in the Drawer header (bodyHl) and in the content (headline)
    const titles = screen.getAllByText('Map Test Metric')

    expect(titles).toHaveLength(2)
    expect(screen.getByText('Select the external account for this metric')).toBeInTheDocument()
  })

  it('renders the default form section', async () => {
    await prepare()

    expect(screen.getByText('Form for default')).toBeInTheDocument()
  })

  it('renders billing entity tabs (excluding default)', async () => {
    await prepare()

    expect(screen.getByText('Entity One')).toBeInTheDocument()
    expect(screen.getByText('Entity Two')).toBeInTheDocument()
  })

  it('renders the first billing entity tab content by default', async () => {
    await prepare()

    expect(screen.getByText('Form for be-1')).toBeInTheDocument()
  })

  it('switches tab content when clicking another billing entity', async () => {
    await prepare()

    // Initially shows be-1
    expect(screen.getByText('Form for be-1')).toBeInTheDocument()

    // Click the second tab
    await userEvent.click(screen.getByText('Entity Two'))

    expect(screen.getByText('Form for be-2')).toBeInTheDocument()
    expect(screen.queryByText('Form for be-1')).not.toBeInTheDocument()
  })

  it('matches snapshot', async () => {
    const { baseElement } = await prepare()

    // Use baseElement to capture the portal-rendered MUI Drawer content
    expect(baseElement).toMatchSnapshot()
  })
})
