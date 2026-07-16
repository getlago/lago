/* eslint-disable no-alert */
import Box from '@mui/material/Box'
import InputAdornment from '@mui/material/InputAdornment'
import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { Icon, IconName } from 'lago-design-system'
import { generatePath } from 'react-router-dom'
import { boolean, number, object, string } from 'yup'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar, AvatarBadge } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { Chip } from '~/components/designSystem/Chip'
import { Drawer } from '~/components/designSystem/Drawer'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { NavigationTab } from '~/components/designSystem/NavigationTab'
import { Popper } from '~/components/designSystem/Popper'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { ShowMoreText } from '~/components/designSystem/ShowMoreText'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status, StatusType } from '~/components/designSystem/Status'
import { ChargeTable, HorizontalDataTable } from '~/components/designSystem/Table'
import { Table } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import {
  ButtonSelectorField,
  Checkbox,
  CheckboxField,
  ComboBoxField,
  DatePickerField,
  JsonEditorField,
  MultipleComboBox,
  MultipleComboBoxField,
  RadioField,
  SwitchField,
  TextInputField,
} from '~/components/form'
import { AmountInputField } from '~/components/form/AmountInput'
import { addToast } from '~/core/apolloClient'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { Link, ONLY_DEV_DESIGN_SYSTEM_ROUTE, ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { DateFormat, intlFormatDateTime } from '~/core/timezone'
import { CurrencyEnum, TimezoneEnum } from '~/generated/graphql'
import {
  chargeTableData,
  currentUsageTableData,
  fakeDataHorizontalTable,
  POSSIBLE_TOAST,
  tableData,
} from '~/pages/__devOnly/fixtures'
import EmptyImage from '~/public/images/maneki/empty.svg'
import ErrorImage from '~/public/images/maneki/error.svg'
import Stripe from '~/public/images/stripe.svg'
import { MenuPopper, PageHeader } from '~/styles'
import { tw } from '~/styles/utils'

import DialogTest from './tabs/DialogTest'
import DrawerTest from './tabs/DrawerTest'
import EditorTest from './tabs/EditorTest'

const FORM_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'form' })
const LINK_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'links' })
const DISPLAY_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'display' })
const BUTTON_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'button' })
const TYPOGRAPHY_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'typography' })
const AVATAR_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'avatar' })
const SKELETON_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'skeleton' })
const TABLE_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'table' })
const DIALOG_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'dialog' })
const DRAWER_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, { tab: 'drawer' })
const RICH_TEXT_EDITOR_TAB_URL = generatePath(ONLY_DEV_DESIGN_SYSTEM_TAB_ROUTE, {
  tab: 'rich-text-editor',
})

const Container = ({ children }: { children: React.ReactNode }) => (
  <div className="px-12 pb-20 pt-8">{children}</div>
)

const Block = ({ children, className }: { children: React.ReactNode; className?: string }) => (
  <div className={tw('mb-6 flex flex-wrap gap-4', className)}>{children}</div>
)

const VerticalBlock = ({
  children,
  className,
}: {
  children: React.ReactNode
  className?: string
}) => <div className={tw('*:mb-4', className)}>{children}</div>

const ComboboxHeader = ({ children }: { children: React.ReactNode }) => (
  <div className="flex w-full gap-1 *:whitespace-nowrap">{children}</div>
)

const DesignSystem = () => {
  const formikProps = useFormik({
    initialValues: {
      checkbox: false,
      amountCents: undefined,
      amountCurrency: CurrencyEnum.Usd,
      date: undefined,
      time: undefined,
      input: undefined,
      inputNumber: undefined,
      switch: true,
      combobox: undefined,
      multipleCombobox: [],
      radio: false,
      buttonSelector: undefined,
      buttonSelector2: 'time',
      checkboxCond1: true,
      checkboxCond2: true,
      json: {
        age: '41 years old',
        home: {
          country: 'United States',
          address: '317 example street',
        },
        friends: [],
      },
      jsonLong: {
        age: '41 years old',
        home: {
          country: 'United States',
          address: '317 example street',
        },
        friends: [
          'Lucille, Ellissa',
          'Korry, Shawn',
          'Auguste, Gina',
          'Guinna, Aime',
          'Faustine, Rozalie',
        ],
      },
      jsonEmpty: undefined,
    },
    validationSchema: object().shape({
      checkbox: boolean().required(),
      amountCurrency: string().required(),
      amountCents: number().required(),
      json: string().required(),
      date: string()
        .required()
        .matches(/1992-05-26/, 'Sorry, you owe her a beer 🍺'),
      time: string().required(),
      input: string()
        .required()
        .matches(/whatever/, "I thought you'd be more fun... 😏"),
      radio: string()
        .required()
        .matches(/whatever/, 'Really ? 🙄'),
      combobox: string().required().matches(/Mike/, "No, it's Mike 😡"),
      buttonSelector: string()
        .required()
        .matches(/whatever/, 'Interesting... '),
    }),
    onSubmit: () => {},
  })

  const getCheckboxValue = (cond1: boolean, cond2: boolean) => {
    if (cond1 && cond2) return true
    if (!cond1 && !cond2) return false
    return undefined
  }

  return (
    <>
      <PageHeader.Wrapper withSide>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          Design System components
        </Typography>
        <Typography variant="caption">Only visible in dev mode</Typography>
      </PageHeader.Wrapper>
      <NavigationTab
        className="px-12"
        name="Design system tab switcher"
        tabs={[
          {
            title: 'Display',
            link: DISPLAY_TAB_URL,
            match: [DISPLAY_TAB_URL, ONLY_DEV_DESIGN_SYSTEM_ROUTE],
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Accordion
                </Typography>
                <Stack gap={6} marginBottom={6}>
                  <Accordion size="medium" summary="medium accordion">
                    <Typography variant="body">Content of the accordion</Typography>
                  </Accordion>
                  <Accordion size="large" summary="large accordion">
                    <Typography variant="body">Content of the accordion</Typography>
                  </Accordion>
                  <Accordion
                    variant="borderless"
                    summary={
                      <div>
                        <Typography variant="subhead1" className="mb-2">
                          borderless accordion
                        </Typography>
                        <Typography variant="caption">Caption</Typography>
                      </div>
                    }
                  >
                    <Typography variant="body">Content of the accordion</Typography>
                  </Accordion>
                </Stack>

                <Typography className="mb-4" variant="headline">
                  Alert
                </Typography>
                <Block>
                  <Alert
                    fullWidth
                    className="md:px-12"
                    type="danger"
                    ButtonProps={{
                      label: 'Retry',
                      onClick: () => alert('Retry clicked'),
                    }}
                  >
                    <Stack>
                      <Typography variant="body" color="grey700">
                        Invoice could not be fully refreshed.
                      </Typography>
                      <Typography variant="caption">
                        An issue with your tax provider connection occurred. Please contact the Lago
                        team to solve this issue.
                      </Typography>
                    </Stack>
                  </Alert>
                  <Alert type="info">I&apos;m an info alert</Alert>
                  <Alert type="success">I&apos;m a success alert</Alert>
                  <Alert type="warning">I&apos;m a warning alert</Alert>
                  <Alert type="danger">I&apos;m a danger alert</Alert>
                </Block>

                <Typography className="mb-4" variant="headline">
                  Chips
                </Typography>
                <Block>
                  <Chip label="Small" size="small" />
                  <Chip label="Default" />
                  <Chip label="Big" size="big" />
                  <Chip label="I have an icon" icon="scissor" />
                  <Chip
                    label="I have an icon and delete"
                    icon="percentage"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                  <Chip
                    label="Tooltip on icon"
                    icon="scissor"
                    deleteIconLabel="Delete"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                  <Chip
                    error
                    label="I have an error"
                    icon="scissor"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                  <Chip type="secondary" label="Small" size="small" />
                  <Chip type="secondary" label="Default" />
                  <Chip type="secondary" label="Big" size="big" />
                  <Chip
                    type="secondary"
                    label="I have an icon and delete"
                    icon="percentage"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                  <Chip
                    type="secondary"
                    label="Tooltip on icon"
                    icon="scissor"
                    deleteIconLabel="Delete"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                  <Chip
                    error
                    type="secondary"
                    label="I have an error"
                    icon="scissor"
                    onDelete={() => {
                      // eslint-disable-next-line no-console
                      console.log('Chip clicked')
                    }}
                  />
                </Block>

                <Typography className="mb-4" variant="headline">
                  Poppers
                </Typography>
                <Block>
                  <Drawer title="Imma supa drawa" opener={<Button>Drawer</Button>}>
                    <iframe
                      title="hey you"
                      src="https://giphy.com/embed/nNxT5qXR02FOM"
                      width="480"
                      height="399"
                      frameBorder="0"
                      allowFullScreen
                    ></iframe>
                  </Drawer>
                  <Tooltip placement="top-end" title="Hola muchacho 🥸!">
                    <Button variant="secondary">Tooltip</Button>
                  </Tooltip>
                  <Popper
                    PopperProps={{ placement: 'bottom-end' }}
                    opener={<Button variant="tertiary">Popper</Button>}
                  >
                    {({ closePopper }) => (
                      <MenuPopper>
                        <Button startIcon="paperclip" variant="quaternary" align="left" fullWidth>
                          I&apos;m lazy
                        </Button>
                        <Button
                          startIcon="plug"
                          variant="quaternary"
                          align="left"
                          fullWidth
                          onClick={() => closePopper()}
                        >
                          I close the popper
                        </Button>
                      </MenuPopper>
                    )}
                  </Popper>
                  <Tooltip
                    placement="top-end"
                    title="Will trigger only if the toast does not already exists"
                  >
                    <Button
                      variant="tertiary"
                      onClick={() => {
                        const toastIndex = Math.floor(Math.random() * POSSIBLE_TOAST.length)

                        addToast(POSSIBLE_TOAST[toastIndex])
                      }}
                    >
                      I trigger a toast
                    </Button>
                  </Tooltip>
                </Block>

                <Typography className="mb-4" variant="headline">
                  Selector
                </Typography>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  Default states
                </Typography>
                <Block>
                  <Selector
                    title="Clickable with chip"
                    subtitle="endContent only, no hover swap"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={
                      <Chip
                        icon="validate-filled"
                        iconSize="medium"
                        iconColor="success"
                        label="Connected"
                      />
                    }
                    onClick={() => alert('Selector clicked')}
                    fullWidth
                  />
                  <Selector
                    title="Selected with subtitle first"
                    subtitle="Subtitle first"
                    titleFirst={false}
                    selected
                    icon="target"
                    endContent={<Chip label="Active" />}
                    onClick={() => alert('Selected clicked')}
                  />
                  <Selector
                    title="Non clickable"
                    subtitle="No onClick, no endContent"
                    titleFirst={false}
                    icon="user"
                  />
                  <Selector
                    title="Disabled with chip"
                    subtitle="Cannot interact"
                    titleFirst={false}
                    disabled
                    icon={
                      <Avatar size="big" variant="connector">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={<Chip label="Connected" />}
                    onClick={() => alert('Should not fire')}
                  />
                </Block>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  Integration patterns — default arrow + hover swap
                </Typography>
                <Block>
                  <Selector
                    title="Not connected"
                    subtitle="Click opens add dialog"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={<Button icon="chevron-right" variant="quaternary" />}
                    onClick={() => alert('Open add dialog')}
                    fullWidth
                  />
                  <Selector
                    title="Connected — hover to see edit"
                    subtitle="endContent swaps to hoverActions on hover"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={
                      <>
                        <Chip label="Connected" />
                        <Button icon="chevron-right" variant="quaternary" />
                      </>
                    }
                    hoverActions={
                      <>
                        <Chip label="Connected" />
                        <SelectorActions
                          actions={[
                            {
                              icon: 'pen',
                              onClick: () => alert('Edit integration'),
                            },
                          ]}
                        />
                      </>
                    }
                    onClick={() => alert('Navigate to integration')}
                    fullWidth
                  />
                  <Selector
                    title="Connected — multiple hover actions"
                    subtitle="Edit and delete on hover"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={
                      <>
                        <Chip label="Connected" />
                        <Button icon="chevron-right" variant="quaternary" />
                      </>
                    }
                    hoverActions={
                      <>
                        <Chip label="Connected" />
                        <SelectorActions
                          actions={[
                            {
                              icon: 'pen',
                              tooltipCopy: 'Edit',
                              onClick: () => alert('Edit'),
                            },
                            {
                              icon: 'trash',
                              tooltipCopy: 'Delete',
                              onClick: () => alert('Delete'),
                            },
                          ]}
                        />
                      </>
                    }
                    onClick={() => alert('Navigate to integration')}
                    fullWidth
                  />
                </Block>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  Multiple hover actions only (no chip on hover)
                </Typography>
                <Block>
                  <Selector
                    title="Item with actions"
                    subtitle="Only action buttons on hover"
                    icon="target"
                    endContent={<Button icon="chevron-right" variant="quaternary" />}
                    hoverActions={
                      <SelectorActions
                        actions={[
                          {
                            icon: 'pen',
                            tooltipCopy: 'Edit',
                            onClick: () => alert('Edit'),
                          },
                          {
                            icon: 'trash',
                            tooltipCopy: 'Delete',
                            onClick: () => alert('Delete'),
                          },
                        ]}
                      />
                    }
                    onClick={() => alert('Navigate')}
                    fullWidth
                  />
                </Block>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  Premium gating — sparkles icon
                </Typography>
                <Block>
                  <Selector
                    title="Premium locked"
                    subtitle="Sparkles shown, no hover swap"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={<Button icon="sparkles" variant="quaternary" disabled />}
                    onClick={() => alert('Open premium warning')}
                    fullWidth
                  />
                </Block>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  External link
                </Typography>
                <Block>
                  <Selector
                    title="Documentation link"
                    subtitle="Opens external URL"
                    icon={
                      <Avatar size="big" variant="connector-full">
                        <Stripe />
                      </Avatar>
                    }
                    endContent={<Button icon="outside" variant="quaternary" />}
                    onClick={() => alert('Open external link')}
                    fullWidth
                  />
                </Block>

                <Typography className="mb-2" variant="bodyHl" color="textSecondary">
                  Authentication patterns — endContent with Popper menu
                </Typography>
                <Block>
                  <Selector
                    title="Enabled method with menu"
                    subtitle="Chip + dots-horizontal Popper"
                    icon={
                      <Avatar size="big" variant="connector">
                        <Icon name="key" color="black" />
                      </Avatar>
                    }
                    endContent={
                      <div className="flex items-center gap-2">
                        <Chip
                          icon="validate-filled"
                          iconSize="medium"
                          iconColor="success"
                          label="Enabled"
                        />
                        <Popper
                          PopperProps={{ placement: 'bottom-end' }}
                          opener={({ onClick }) => (
                            <Button
                              icon="dots-horizontal"
                              variant="quaternary"
                              onClick={(e) => {
                                e.stopPropagation()
                                onClick()
                              }}
                            />
                          )}
                        >
                          {({ closePopper }) => (
                            <div className="flex flex-col p-2">
                              <Button
                                startIcon="eye-hidden"
                                variant="quaternary"
                                align="left"
                                onClick={(e) => {
                                  e.stopPropagation()
                                  alert('Disable method')
                                  closePopper()
                                }}
                              >
                                Disable
                              </Button>
                            </div>
                          )}
                        </Popper>
                      </div>
                    }
                  />
                  <Selector
                    title="Disabled method with menu"
                    subtitle="Chip + dots-horizontal Popper"
                    icon={
                      <Avatar size="big" variant="connector">
                        <Icon name="google" size="medium" />
                      </Avatar>
                    }
                    endContent={
                      <div className="flex items-center gap-2">
                        <Chip
                          icon="close-circle-filled"
                          iconSize="medium"
                          iconColor="disabled"
                          label="Disabled"
                        />
                        <Popper
                          PopperProps={{ placement: 'bottom-end' }}
                          opener={({ onClick }) => (
                            <Button
                              icon="dots-horizontal"
                              variant="quaternary"
                              onClick={(e) => {
                                e.stopPropagation()
                                onClick()
                              }}
                            />
                          )}
                        >
                          {({ closePopper }) => (
                            <div className="flex flex-col p-2">
                              <Button
                                startIcon="plus"
                                variant="quaternary"
                                align="left"
                                onClick={(e) => {
                                  e.stopPropagation()
                                  alert('Enable method')
                                  closePopper()
                                }}
                              >
                                Enable
                              </Button>
                            </div>
                          )}
                        </Popper>
                      </div>
                    }
                  />
                </Block>

                <Typography className="mb-4" variant="headline">
                  Status
                </Typography>
                <VerticalBlock>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Success
                    </Typography>
                    <Status
                      type={StatusType.success}
                      label="succeeded"
                      endIcon="warning-unfilled"
                    />
                    <Status type={StatusType.success} label="finalized" />
                    <Status type={StatusType.success} label="active" />
                    <Status type={StatusType.success} label="pay" />
                    <Status type={StatusType.success} label="available" />
                    <Status
                      type={StatusType.success}
                      label="refunded"
                      labelVariables={{ date: '2024-04-12' }}
                    />
                  </Block>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Warning
                    </Typography>
                    <Status type={StatusType.warning} label="failed" endIcon="warning-unfilled" />
                  </Block>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Outline
                    </Typography>
                    <Status type={StatusType.outline} label="draft" endIcon="warning-unfilled" />
                  </Block>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Default
                    </Typography>
                    <Status type={StatusType.default} label="pending" endIcon="warning-unfilled" />
                    <Status type={StatusType.default} label="toPay" />
                    <Status type={StatusType.default} label="n/a" />
                  </Block>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Danger
                    </Typography>
                    <Status type={StatusType.danger} label="disputed" endIcon="warning-unfilled" />
                    <Status type={StatusType.danger} label="disputeLost" />
                    <Status
                      type={StatusType.danger}
                      label="disputeLostOn"
                      labelVariables={{ date: '2024-04-12' }}
                    />
                    <Status type={StatusType.danger} label="terminated" />
                    <Status type={StatusType.danger} label="consumed" />
                    <Status type={StatusType.danger} label="voided" />
                  </Block>
                  <Block className="mb-0">
                    <Typography className="mb-4" variant="bodyHl" color="textSecondary">
                      Disabled
                    </Typography>
                    <Status type={StatusType.disabled} label="voided" endIcon="warning-unfilled" />
                  </Block>
                </VerticalBlock>

                <Typography className="mb-4" variant="headline">
                  ShowMoreText
                </Typography>
                <Block>
                  <ShowMoreText
                    text="Lorem ipsum dolor sit amet consectetur adipisicing elit. Accusantium praesentium minus necessitatibus. Placeat, ratione ipsam dolor, quas iste obcaecati tenetur esse tempora quidem eveniet iure quasi repellat debitis doloribus? Distinctio iure quisquam ipsam minus dolorum corporis, eligendi iusto. Animi assumenda reprehenderit atque corrupti, a iste illo porro facilis maxime. Quod eaque ratione, ullam tempore blanditiis placeat odit, assumenda labore accusamus libero nostrum qui et architecto inventore atque, veritatis vitae nisi quas veniam sit! Quasi natus, neque sed soluta perspiciatis officiis?"
                    limit={30}
                  />
                </Block>
                <Block>
                  <ShowMoreText
                    text="Custom show more. Lorem ipsum dolor sit amet consectetur adipisicing elit. Accusantium praesentium minus necessitatibus. Placeat, ratione ipsam dolor, quas iste obcaecati tenetur esse tempora quidem eveniet iure quasi repellat debitis doloribus? Distinctio iure quisquam ipsam minus dolorum corporis, eligendi iusto. Animi assumenda reprehenderit atque corrupti, a iste illo porro facilis maxime. Quod eaque ratione, ullam tempore blanditiis placeat odit, assumenda labore accusamus libero nostrum qui et architecto inventore atque, veritatis vitae nisi quas veniam sit! Quasi natus, neque sed soluta perspiciatis officiis?"
                    limit={30}
                    showMore="Please show more"
                  />
                </Block>
                <Block>
                  <ShowMoreText
                    text="Custom show more with button. Lorem ipsum dolor sit amet consectetur adipisicing elit. Accusantium praesentium minus necessitatibus. Placeat, ratione ipsam dolor, quas iste obcaecati tenetur esse tempora quidem eveniet iure quasi repellat debitis doloribus? Distinctio iure quisquam ipsam minus dolorum corporis, eligendi iusto. Animi assumenda reprehenderit atque corrupti, a iste illo porro facilis maxime. Quod eaque ratione, ullam tempore blanditiis placeat odit, assumenda labore accusamus libero nostrum qui et architecto inventore atque, veritatis vitae nisi quas veniam sit! Quasi natus, neque sed soluta perspiciatis officiis?"
                    limit={30}
                    showMore={<Button variant="secondary" size="small" icon="plus" />}
                  />
                </Block>
                <Block>
                  <GenericPlaceholder
                    title="Something went wrong"
                    subtitle="Please refresh the page or contact us if the error persists."
                    buttonTitle="Refresh the page"
                    buttonVariant="primary"
                    buttonAction={() => location.reload()}
                    image={<ErrorImage width="136" height="104" />}
                  />
                  <GenericPlaceholder
                    title="This add-on cannot be found"
                    subtitle="Could you enter another keyword?"
                    image={<EmptyImage width="136" height="104" />}
                  />
                </Block>
              </Container>
            ),
          },
          {
            title: 'Skeleton',
            link: SKELETON_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Skeleton
                </Typography>
                <Block>
                  <Skeleton variant="connectorAvatar" size="small" />
                  <Skeleton variant="connectorAvatar" size="medium" />
                  <Skeleton variant="connectorAvatar" size="large" />
                  <Skeleton variant="userAvatar" size="small" />
                  <Skeleton variant="userAvatar" size="medium" />
                  <Skeleton variant="userAvatar" size="large" />
                </Block>
                <div>
                  <Skeleton className="mb-4" size="large" variant="circular" />
                  <Skeleton className="mb-4 h-3 w-30" variant="text" />
                  <Skeleton className="mb-4 h-3 w-1/2" variant="text" />
                  <Skeleton className="mb-4 h-3" variant="text" color="dark" />
                </div>
              </Container>
            ),
          },
          {
            title: 'Table',
            link: TABLE_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Table
                </Typography>
                <Block>
                  <ChargeTable
                    name="graduated-charge-table"
                    data={chargeTableData}
                    onDeleteRow={() => {}}
                    columns={[
                      {
                        title: (
                          <Typography className="px-4" variant="bodyHl" color="grey700">
                            Name
                          </Typography>
                        ),
                        size: 300,
                        content: (row) => (
                          <div className="flex items-center gap-2 px-2">
                            <Avatar variant="user" identifier={row.name} size="small" />
                            <Typography>{row.name}</Typography>
                          </div>
                        ),
                      },
                      {
                        title: (
                          <Typography className="px-4" variant="bodyHl" color="grey700">
                            Job
                          </Typography>
                        ),
                        size: 124,
                        mapKey: 'job',
                      },
                      {
                        title: (
                          <Typography className="px-4" variant="bodyHl" color="grey700">
                            Icon
                          </Typography>
                        ),
                        size: 124,
                        content: (row) => (
                          <div className="flex items-center gap-2 px-2">
                            <Icon color="primary" name={row.icon as IconName} />
                          </div>
                        ),
                      },
                    ]}
                  />
                </Block>
                <Typography className="mb-4" variant="headline">
                  Display Table
                </Typography>
                <Block>
                  <Table
                    name="display-table"
                    containerSize={{
                      default: 4,
                      md: 48,
                    }}
                    data={tableData}
                    isLoading={false}
                    columns={[
                      {
                        key: 'status',
                        title: 'Status',
                        content: (row) => <Status label={row.status} type={StatusType.success} />,
                      },
                      {
                        key: 'id',
                        title: 'Invoice number',
                        content: (row) => <Typography variant="captionCode">{row.id}</Typography>,
                      },
                      {
                        key: 'amount',
                        title: 'Amount',

                        content: (row) => (
                          <Button
                            onClick={() => alert(`You clicked on ${row.amount}`)}
                            size="small"
                            variant="quaternary"
                          >
                            {intlFormatNumber(row.amount)}
                          </Button>
                        ),
                      },
                      {
                        key: 'customer',
                        title: 'Customer',
                        content: (row) => (
                          <Typography variant="captionCode" color="success600">
                            <Link to={'/'}>{row.customer}</Link>
                          </Typography>
                        ),
                      },
                      {
                        key: 'date',
                        title: 'Issuing date',
                        content: (row) => row.date,
                      },
                    ]}
                    onRowActionLink={(item) => `you clicked on ${item.id}`}
                    actionColumn={(currentItem) => [
                      currentItem.amount > 1000
                        ? {
                            title: 'Edit',
                            startIcon: 'pen',
                            onAction: (item) => {
                              alert(`You edited ${item.id}`)
                            },
                          }
                        : null,
                      {
                        title: 'Delete',
                        startIcon: 'trash',
                        onAction: (item) => {
                          alert(`You deleted ${item.id}`)
                        },
                      },
                    ]}
                  />

                  <Table
                    name="display-table"
                    containerSize={0}
                    rowSize={72}
                    data={currentUsageTableData}
                    isLoading={false}
                    columns={[
                      {
                        key: 'chargeName',
                        title: 'Customer',
                        content: (row) => (
                          <Box display={'grid'}>
                            <Typography variant="body" color="grey700" noWrap>
                              {row.chargeName}
                            </Typography>
                            <Typography variant="caption" color="grey600" noWrap>
                              {row.chargeCode}
                              {row.hasFilterBreakdown ? ' • with breakdown' : ''}
                            </Typography>
                          </Box>
                        ),
                      },
                      {
                        key: 'units',
                        title: 'Units',
                        content: (row) => (
                          <Typography variant="body" color="grey700">
                            {row.units}
                          </Typography>
                        ),
                      },
                      {
                        key: 'amount',
                        title: 'Amount',
                        textAlign: 'right',
                        content: (row) => (
                          <Typography variant="body" color="grey700">
                            {intlFormatNumber(row.amount)}
                          </Typography>
                        ),
                      },
                    ]}
                    onRowActionLink={(item) => `you clicked on ${item.id}`}
                  />

                  <Typography className="mb-4" variant="headline">
                    Virtualized horizontal Table
                  </Typography>

                  <AnalyticsStateProvider>
                    <HorizontalDataTable
                      leftColumnWidth={130}
                      data={fakeDataHorizontalTable}
                      rows={[
                        {
                          label: 'Breakout',
                          key: 'end_of_period_dt',
                          type: 'header',
                          content: (item) => {
                            return (
                              <Typography variant="captionHl">
                                {
                                  intlFormatDateTime(item.end_of_period_dt, {
                                    timezone: TimezoneEnum.TzUtc,
                                    formatDate: DateFormat.DATE_MONTH_YEAR,
                                  }).date
                                }
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'New',
                          key: 'mrr_new',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.mrr_new > 0,
                                  'text-grey-500': item.mrr_new === 0,
                                  'text-red-600': item.mrr_new < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.mrr_new || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Expansion',
                          key: 'mrr_expansion',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.mrr_expansion > 0,
                                  'text-grey-500': item.mrr_expansion === 0,
                                  'text-red-600': item.mrr_expansion < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.mrr_expansion || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Contraction',
                          key: 'mrr_contraction',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.mrr_contraction > 0,
                                  'text-grey-500': item.mrr_contraction === 0,
                                  'text-red-600': item.mrr_contraction < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.mrr_contraction || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Churn',
                          key: 'mrr_churn',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-red-600': item.mrr_churn < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.mrr_churn || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Summary',
                          key: 'end_of_period_dt',
                          type: 'header',
                          content: (item) => {
                            return (
                              <Typography variant="captionHl">
                                {
                                  intlFormatDateTime(item.end_of_period_dt, {
                                    timezone: TimezoneEnum.TzUtc,
                                    formatDate: DateFormat.DATE_MONTH_YEAR,
                                  }).date
                                }
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Starting MRR',
                          key: 'starting_mrr',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.starting_mrr > 0,
                                  'text-grey-500': item.starting_mrr === 0,
                                  'text-red-600': item.starting_mrr < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.starting_mrr || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Change',
                          key: 'mrr_change',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.mrr_change > 0,
                                  'text-grey-500': item.mrr_change === 0,
                                  'text-red-600': item.mrr_change < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.mrr_change || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'Ending MRR',
                          key: 'ending_mrr',
                          type: 'data',
                          content: (item) => {
                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': item.ending_mrr > 0,
                                  'text-grey-500': item.ending_mrr === 0,
                                  'text-red-600': item.ending_mrr < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(
                                    item.ending_mrr || 0,
                                    formikProps.values.amountCurrency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                        {
                          label: 'TOTAL',
                          key: 'id',
                          type: 'data',
                          content: (item) => {
                            const total =
                              item.mrr_new +
                              item.mrr_expansion +
                              item.mrr_contraction -
                              item.mrr_churn

                            return (
                              <Typography
                                variant="body"
                                className={tw({
                                  'text-green-600': total > 0,
                                  'text-grey-500': total === 0,
                                  'text-red-600': total < 0,
                                })}
                              >
                                {intlFormatNumber(
                                  deserializeAmount(total || 0, formikProps.values.amountCurrency),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency: formikProps.values.amountCurrency,
                                  },
                                )}
                              </Typography>
                            )
                          },
                        },
                      ]}
                    />
                  </AnalyticsStateProvider>
                </Block>
              </Container>
            ),
          },
          {
            title: 'Avatar',
            link: AVATAR_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Avatar
                </Typography>
                <Typography className="mb-4" variant="subhead1">
                  Variants
                </Typography>
                <Block>
                  <Tooltip title="Connector with icon">
                    <Avatar variant="connector">
                      <Icon name="pulse" color="dark" />
                    </Avatar>
                  </Tooltip>
                  <Tooltip title="Connector with avatar badge">
                    <Avatar variant="connector">
                      <Icon name="pulse" color="dark" />
                      <AvatarBadge icon="stop" color="error" />
                    </Avatar>
                  </Tooltip>
                  <Tooltip title="Connector with image">
                    <Avatar variant="connector-full">
                      <Stripe />
                    </Avatar>
                  </Tooltip>
                  <Tooltip title="Company">
                    <Avatar
                      variant="company"
                      identifier="Lago Corp"
                      initials={'Lago Corp'.split(' ').reduce((acc, n) => (acc = acc + n[0]), '')}
                    />
                  </Tooltip>
                  <Tooltip title="User">
                    <Avatar variant="user" identifier="Morguy" initials="ML" />
                  </Tooltip>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Size
                </Typography>
                <Block>
                  <div className="not-last-child:mb-4">
                    <Avatar variant="user" size="small" identifier="Morguy" initials="ML" />
                    <Avatar variant="user" size="intermediate" identifier="Morguy" initials="ML" />
                    <Avatar variant="user" size="medium" identifier="Morguy" initials="ML" />
                    <Avatar variant="user" size="large" identifier="Morguy" initials="ML" />
                  </div>
                  <div className="not-last-child:mb-4">
                    <Avatar variant="company" size="small" identifier="Lago Corp" />
                    <Avatar variant="company" size="intermediate" identifier="Lago Corp" />
                    <Avatar variant="company" size="medium" identifier="Lago Corp" />
                    <Avatar variant="company" size="large" identifier="Lago Corp" />
                  </div>
                  <div className="not-last-child:mb-4">
                    <Avatar variant="connector" size="tiny">
                      <Icon name="pulse" color="dark" />
                    </Avatar>
                    <Avatar variant="connector" size="small">
                      <Icon name="pulse" color="dark" />
                    </Avatar>
                    <Avatar variant="connector" size="intermediate">
                      <Icon name="pulse" color="dark" />
                    </Avatar>
                    <Avatar variant="connector" size="medium">
                      <Icon name="pulse" color="dark" />
                    </Avatar>
                    <Avatar variant="connector" size="big">
                      <Icon name="pulse" color="dark" />
                      <AvatarBadge icon="stop" color="info" size="big" />
                    </Avatar>
                    <Avatar variant="connector" size="large">
                      <Icon name="pulse" color="dark" />
                      <AvatarBadge icon="stop" color="warning" size="large" />
                    </Avatar>
                  </div>

                  <Avatar variant="connector" size="medium">
                    <Stripe />
                  </Avatar>
                  <Avatar variant="connector" size="large">
                    <Stripe />
                  </Avatar>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Colors
                </Typography>
                <Typography className="mb-4">
                  Color is defined automatically based on initials or identifier
                </Typography>
                <Block>
                  <Avatar variant="company" identifier="AA" />
                  <Avatar variant="company" identifier="AB" />
                  <Avatar variant="company" identifier="AC" />
                  <Avatar variant="company" identifier="AD" />
                  <Avatar variant="company" identifier="AE" />
                  <Avatar variant="company" identifier="AF" />
                  <Avatar variant="company" identifier="AG" />
                  <Avatar variant="company" identifier="AH" />
                </Block>
              </Container>
            ),
          },
          {
            title: 'Typography',
            link: TYPOGRAPHY_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Typography
                </Typography>
                <Block className="mb-0">
                  <VerticalBlock className="mr-12">
                    <Typography className="mb-4" variant="subhead1">
                      Variant
                    </Typography>
                    <Typography variant="headline">Headline</Typography>
                    <Typography variant="subhead1">Subhead</Typography>
                    <Typography variant="bodyHl">BodyHl</Typography>
                    <Typography variant="body">Body</Typography>
                    <Typography variant="button">Button</Typography>
                    <Typography variant="caption">Caption</Typography>
                    <Typography variant="captionHl">CaptionHl</Typography>
                    <Typography variant="captionCode">CaptionCode</Typography>
                    <Typography variant="note">Note</Typography>
                    <Typography variant="noteHl">NoteHl</Typography>
                    <Typography blur>Amma blurred text</Typography>
                    <Typography
                      color="textSecondary"
                      html="I'm a bit <b>special</b>, I <i>understand</i> html"
                    />
                  </VerticalBlock>
                  <VerticalBlock>
                    <Typography className="mb-4" variant="subhead1">
                      Color
                    </Typography>
                    <Typography color="textSecondary">color textSecondary</Typography>
                    <Typography color="textPrimary">color textPrimary</Typography>
                    <Typography color="primary600">color primary600</Typography>
                    <Typography color="grey700">color grey700</Typography>
                    <Typography color="grey600">color grey600</Typography>
                    <Typography color="grey500">color grey500</Typography>
                    <Typography color="disabled">color disabled</Typography>
                    <Typography color="danger600">color danger600</Typography>
                    <Typography color="white">color white</Typography>
                  </VerticalBlock>
                </Block>
                <Typography className="mb-4 mt-8" variant="headline">
                  TypographyWithCopy
                </Typography>
                <Block className="mb-0">
                  <VerticalBlock>
                    <TypographyWithCopy variant="body" color="grey700">
                      db7a5c02-a7c8-4c48-a44f-3e5b1f2a9e3d
                    </TypographyWithCopy>
                    <TypographyWithCopy variant="captionCode" color="grey700">
                      sub_ext_12345
                    </TypographyWithCopy>
                    <TypographyWithCopy variant="caption" color="grey600">
                      PLAN_CODE_MONTHLY
                    </TypographyWithCopy>
                    <TypographyWithCopy variant="bodyHl" color="grey700">
                      INV-2024-001-234
                    </TypographyWithCopy>
                  </VerticalBlock>
                </Block>
              </Container>
            ),
          },
          {
            title: 'Buttons',
            link: BUTTON_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Button
                </Typography>

                <Typography className="mb-4" variant="subhead1">
                  General use
                </Typography>
                <Block>
                  <Button variant="primary" size="large">
                    Large
                  </Button>
                  <Button variant="primary" size="medium">
                    Medium
                  </Button>
                  <Button variant="primary" size="small">
                    Small
                  </Button>
                  <Button variant="primary" icon="coupon" size="large" />
                  <Button variant="primary" icon="download" size="medium" />
                  <Button variant="primary" icon="trash" size="small" />
                  <Button variant="primary" endIcon="rocket">
                    End Icon
                  </Button>
                  <Button variant="primary" startIcon="rocket">
                    Start Icon
                  </Button>
                  <Button variant="primary" loading>
                    Loading
                  </Button>
                  <Button
                    variant="primary"
                    onClick={async () => await new Promise((r) => setTimeout(r, 1000))}
                  >
                    With Promise
                  </Button>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Primary
                </Typography>
                <Block>
                  <Button variant="primary">Default</Button>
                  <Button variant="primary" disabled>
                    Disabled
                  </Button>
                  <Button variant="primary" danger>
                    Danger
                  </Button>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Secondary
                </Typography>
                <Block>
                  <Button variant="secondary">Default</Button>
                  <Button variant="secondary" size="large">
                    Large
                  </Button>
                  <Button variant="secondary" size="medium">
                    Medium
                  </Button>
                  <Button variant="secondary" size="small">
                    Small
                  </Button>
                  <Button variant="secondary" disabled>
                    Disabled
                  </Button>
                  <Button variant="secondary" danger>
                    Danger
                  </Button>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Tertiary
                </Typography>
                <Block>
                  <Button variant="tertiary">Default</Button>
                  <Button variant="tertiary" size="large">
                    Large
                  </Button>
                  <Button variant="tertiary" size="medium">
                    Medium
                  </Button>
                  <Button variant="tertiary" size="small">
                    Small
                  </Button>
                  <Button variant="tertiary" disabled>
                    Disabled
                  </Button>
                  <Button variant="tertiary" danger>
                    Danger
                  </Button>
                </Block>

                <Typography className="mb-4" variant="subhead1">
                  Quaternary
                </Typography>
                <Block>
                  <Button variant="quaternary">Default</Button>
                  <Button variant="quaternary" size="large">
                    Large
                  </Button>
                  <Button variant="quaternary" size="medium">
                    Medium
                  </Button>
                  <Button variant="quaternary" size="small">
                    small
                  </Button>
                  <Button variant="quaternary" startIcon="plus" size="small">
                    Add
                  </Button>
                  <Button variant="quaternary" disabled>
                    Disabled
                  </Button>
                  <Button variant="quaternary" danger>
                    Danger
                  </Button>
                </Block>

                <section>
                  <Typography className="mb-4" variant="subhead1">
                    Inline
                  </Typography>
                  <div className="mb-4 flex flex-wrap gap-4">
                    <Button variant="inline">Default</Button>
                    <Button variant="inline" size="large">
                      Large
                    </Button>
                    <Button variant="inline" size="medium">
                      Medium
                    </Button>
                    <Button variant="inline" size="small">
                      small
                    </Button>
                    <Button variant="inline" startIcon="plus" size="small">
                      Add
                    </Button>
                    <Button variant="inline" startIcon="apps" disabled>
                      Disabled
                    </Button>
                    <Button variant="inline" danger>
                      Danger
                    </Button>
                  </div>
                </section>

                <Typography className="mb-4" variant="subhead1">
                  Google connect
                </Typography>
                <Block>
                  <Button fullWidth startIcon="google" size="large" variant="tertiary">
                    Log In with Google
                  </Button>
                </Block>
              </Container>
            ),
          },
          {
            title: 'Form',
            link: FORM_TAB_URL,
            component: (
              <Container>
                <form onSubmit={(e) => e.preventDefault()}>
                  <Typography className="mb-4" variant="headline">
                    Form
                  </Typography>

                  <Typography className="mb-4" variant="subhead1">
                    Checkbox
                  </Typography>

                  <Block>
                    <Checkbox
                      canBeIndeterminate
                      name="checkboxCond3"
                      value={getCheckboxValue(
                        formikProps.values.checkboxCond1,
                        formikProps.values.checkboxCond2,
                      )}
                      onChange={(e, value) => {
                        if (value) {
                          formikProps.setFieldValue('checkboxCond1', true)
                          formikProps.setFieldValue('checkboxCond2', true)
                        } else {
                          formikProps.setFieldValue('checkboxCond1', false)
                          formikProps.setFieldValue('checkboxCond2', false)
                        }
                      }}
                      label="Accept all conditions or else you won't be able to become the incredibly talented person you want to become (we know, life is unfair)"
                      error={
                        !formikProps.values.checkboxCond1 || !formikProps.values.checkboxCond2
                          ? 'Sorry you need to accept both'
                          : undefined
                      }
                    />

                    <CheckboxField
                      name="checkboxCond1"
                      formikProps={formikProps}
                      value={formikProps.values.checkboxCond1}
                      label="Accept the insane condition"
                    />

                    <CheckboxField
                      name="checkboxCond2"
                      formikProps={formikProps}
                      value={formikProps.values.checkboxCond2}
                      label="Accept the smart condition"
                    />

                    <CheckboxField
                      name="checkboxCond1"
                      formikProps={formikProps}
                      disabled
                      value={formikProps.values.checkboxCond1}
                      label="Insane condition you can't remove"
                    />

                    <CheckboxField
                      name="checkboxCond2"
                      formikProps={formikProps}
                      disabled
                      value={formikProps.values.checkboxCond2}
                      label="Smart condition you can't remove"
                    />

                    <CheckboxField
                      name="checkboxCond2"
                      formikProps={formikProps}
                      value={formikProps.values.checkboxCond2}
                      label="Label"
                      sublabel="Sublabel"
                    />
                    <CheckboxField
                      disabled
                      name="checkboxCond2"
                      formikProps={formikProps}
                      value={formikProps.values.checkboxCond2}
                      label="Label"
                      sublabel="Sublabel"
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    ButtonSelector
                  </Typography>
                  <Block>
                    <ButtonSelectorField
                      name="buttonSelector"
                      label="You'd rather..."
                      description="Be careful with your choice"
                      infoText="You WILL be judge on the answer"
                      formikProps={formikProps}
                      options={[
                        {
                          label: '...talk like Yoda',
                          value: 'yoda',
                        },
                        {
                          label: '...Breath like Darth Vader',
                          value: 'vador',
                        },
                      ]}
                    />
                    <ButtonSelectorField
                      name="buttonSelector"
                      label="You'd rather..."
                      formikProps={formikProps}
                      disabled
                      options={[
                        {
                          label: '...talk like Yoda',
                          value: 'yoda',
                        },
                        {
                          label: '...Breath like Darth Vader',
                          value: 'vador',
                        },
                      ]}
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    Switch
                  </Typography>
                  <Block>
                    <SwitchField
                      name="switch"
                      formikProps={formikProps}
                      label="How do you feel today ?"
                      subLabel={formikProps.values.switch ? '' : 'Wanna talk about it ? Call 911.'}
                    />
                    <SwitchField
                      name="switch"
                      formikProps={formikProps}
                      label="Disabled"
                      disabled
                    />
                    <SwitchField
                      name="switch"
                      formikProps={formikProps}
                      label="How do you feel today ?"
                      subLabel="I really wanna know"
                      labelPosition="left"
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    Combobox
                  </Typography>
                  <Block>
                    <ComboBoxField
                      name="combobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                        description: `I am a description for ${letter}`,
                      }))}
                      label="Grouped by - virtualized"
                      description="You can type anything to see the magic happen"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                      }))}
                      label="Not grouped - virtualized"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      virtualized={false}
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                      }))}
                      label="Not grouped - normal"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      virtualized={false}
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        description: `I am a description for ${letter}`,
                      }))}
                      label="With description"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      virtualized={false}
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                      }))}
                      renderGroupHeader={{
                        '0': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The good •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Based on several survey
                            </Typography>
                          </ComboboxHeader>
                        ),
                        '1': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The bad •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Because I say so
                            </Typography>
                          </ComboboxHeader>
                        ),
                        '2': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The ugly •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Don&apos;t look at it
                            </Typography>
                          </ComboboxHeader>
                        ),
                      }}
                      label="Grouped by - normal - custom headers"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      virtualized={false}
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                      }))}
                      renderGroupHeader={{
                        '0': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The good •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Based on several survey
                            </Typography>
                          </ComboboxHeader>
                        ),
                        '1': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The bad •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Because I say so
                            </Typography>
                          </ComboboxHeader>
                        ),
                        '2': (
                          <ComboboxHeader>
                            <Typography component="span" variant="captionHl" color="textSecondary">
                              The ugly •
                            </Typography>
                            <Typography component="span" variant="caption" noWrap>
                              Don&apos;t look at it
                            </Typography>
                          </ComboboxHeader>
                        ),
                      }}
                      renderGroupInputStartAdornment={{
                        0: 'The good',
                        1: 'The bad',
                        2: 'The ugly',
                      }}
                      label="Grouped by - normal - custom headers - Input start adornment"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      virtualized={false}
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                        description: `I am a description for ${letter}`,
                      }))}
                      label="Grouped by with description"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />

                    <ComboBoxField
                      name="combobox"
                      data={[]}
                      label="Loading"
                      placeholder="But who is it anyway ?"
                      loading
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      name="combobox"
                      data={[]}
                      label="Disabled"
                      placeholder="You don't get to answer"
                      disabled
                      formikProps={formikProps}
                    />

                    <MultipleComboBoxField
                      name="multipleCombobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                      }))}
                      label="Multiple"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <MultipleComboBoxField
                      name="multipleCombobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        description: `I am a description for ${letter}`,
                      }))}
                      label="Multiple with description"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <MultipleComboBoxField
                      disableCloseOnSelect
                      name="multipleCombobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                        description: `I am a description for ${letter}`,
                      }))}
                      label="Multiple disableCloseOnSelect"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <MultipleComboBoxField
                      freeSolo
                      name="multipleCombobox"
                      data={'abcdefghijklmnopqrstuvwxyz'.split('').map((letter, i) => ({
                        value: `${letter}-${i}`,
                        group: Math.round(i / 5) + '',
                      }))}
                      label="Multiple Free Solo"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    <MultipleComboBoxField
                      freeSolo
                      showOptionsOnlyWhenTyping
                      name="multipleCombobox"
                      label="Multiple No Data freeSolo showOptionsOnlyWhenTyping"
                      placeholder="Placeholder"
                      formikProps={formikProps}
                    />
                    {formikProps.values.multipleCombobox.length > 0 && (
                      <Stack gap={1} direction="row" flexWrap="wrap">
                        {formikProps.values.multipleCombobox.map(
                          (value: { value: string }, index) => (
                            <Chip
                              key={index}
                              label={value.value}
                              onDelete={() => {
                                const newValues = formikProps.values.multipleCombobox.filter(
                                  (v) => v !== value,
                                )

                                formikProps.setFieldValue('multipleCombobox', newValues)
                              }}
                            />
                          ),
                        )}
                      </Stack>
                    )}
                    <MultipleComboBox
                      freeSolo
                      hideTags
                      disableClearable
                      showOptionsOnlyWhenTyping
                      data={[]}
                      onChange={(newValue) =>
                        formikProps.setFieldValue('multipleCombobox', newValue)
                      }
                      value={formikProps.values.multipleCombobox}
                      label="Multiple No Data freeSolo hideTags disableClearable allowSameValue showOptionsOnlyWhenTyping"
                      placeholder="Placeholder"
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    Radio
                  </Typography>
                  <Block>
                    <RadioField
                      name="radio"
                      formikProps={formikProps}
                      value="chocolatine"
                      label="Chocolatine"
                    />
                    <RadioField
                      name="radio"
                      formikProps={formikProps}
                      value="painauchocolat"
                      label="Pain au chocolat"
                      sublabel="The right answer"
                    />
                    <RadioField
                      value="painauchocolat"
                      name="radio"
                      formikProps={formikProps}
                      label="Disabled"
                      sublabel="I'm disabled too"
                      disabled
                    />
                    <RadioField
                      name="radio"
                      formikProps={formikProps}
                      value="painauchocolat"
                      label="Radio with a very long label - Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                      sublabel="The right answer"
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    DatePicker
                  </Typography>
                  <Block className="min-w-[325px]">
                    <DatePickerField
                      name="date"
                      label="When is Morguy's birthday ?"
                      formikProps={formikProps}
                    />
                    <DatePickerField
                      name="date"
                      label="DatePicker with helper"
                      helperText="I'm here to help"
                      formikProps={formikProps}
                    />
                    <DatePickerField
                      name="date"
                      label="DatePicker disabled"
                      disabled
                      formikProps={formikProps}
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    AmountInput
                  </Typography>
                  <Block>
                    <AmountInputField
                      beforeChangeFormatter={['positiveNumber']}
                      currency={formikProps.values.amountCurrency}
                      formikProps={formikProps}
                      label="Amount"
                      name="amountCents"
                      description='Amount in "cents" (1€ = 100 cents)'
                    />
                    <ComboBoxField
                      name="amountCurrency"
                      data={Object.values(CurrencyEnum).map((currencyType) => ({
                        value: currencyType,
                      }))}
                      label="currency"
                      description="Select your currency"
                      placeholder="Placeholder"
                      isEmptyNull={false}
                      disableClearable
                      formikProps={formikProps}
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    TextInput
                  </Typography>
                  <Block>
                    <TextInputField
                      label="Label"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      InputProps={{
                        endAdornment: <InputAdornment position="end">Dias</InputAdornment>,
                      }}
                    />
                    <TextInputField
                      label="With decimal formatter"
                      name="inputNumber"
                      placeholder="Type number"
                      beforeChangeFormatter={['decimal']}
                      formikProps={formikProps}
                    />
                    <TextInputField
                      label="With triDecimal formatter"
                      name="inputNumber"
                      placeholder="Type number"
                      beforeChangeFormatter={['triDecimal']}
                      formikProps={formikProps}
                    />
                    <TextInputField
                      label="With quadDecimal formatter"
                      name="inputNumber"
                      placeholder="Type number"
                      beforeChangeFormatter={['quadDecimal']}
                      formikProps={formikProps}
                    />
                    <TextInputField
                      label="Cleanable"
                      name="input"
                      placeholder="Type something"
                      formikProps={formikProps}
                      cleanable
                    />
                    <TextInputField
                      label="Password"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      password
                    />
                    <TextInputField
                      label="With infotext"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      infoText="I'm giving you some infos"
                    />
                    <TextInputField
                      label="Disabled"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      disabled
                      InputProps={{
                        endAdornment: <InputAdornment position="end">Dias</InputAdornment>,
                      }}
                    />
                    <TextInputField
                      label="With helpertext"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      helperText="I'm here to help"
                    />
                    <TextInputField
                      label="With description"
                      placeholder="Type something"
                      name="input"
                      formikProps={formikProps}
                      description="I'm here to help"
                    />
                  </Block>

                  <Typography className="mb-4" variant="subhead1">
                    JSON Editor
                  </Typography>
                  <Block>
                    <JsonEditorField
                      name="json"
                      label="With small editor and overlay"
                      description='Click on "expand" to remove the overlay'
                      infoText="Some tips"
                      formikProps={formikProps}
                      onExpand={(deleteOverlay) => {
                        deleteOverlay()
                      }}
                      helperText="Until you can't see the last line in the editor, you will see the expand overlay"
                    />

                    <JsonEditorField
                      name="jsonLong"
                      label="With height"
                      formikProps={formikProps}
                      height="300px"
                    />
                  </Block>

                  <Button onClick={formikProps.submitForm}>Check your answers</Button>
                </form>
              </Container>
            ),
          },
          {
            title: 'Links',
            link: LINK_TAB_URL,
            component: (
              <Container>
                <Typography className="mb-4" variant="headline">
                  Links
                </Typography>
                <Typography className="mb-4" variant="subhead1">
                  Link in navigation tabs with &#60;ButtonLink/&#62;
                </Typography>
                <Block>
                  <ButtonLink type="tab" icon="rocket" to={ONLY_DEV_DESIGN_SYSTEM_ROUTE}>
                    Non active Link
                  </ButtonLink>
                  <ButtonLink type="tab" active icon="plug" to={ONLY_DEV_DESIGN_SYSTEM_ROUTE}>
                    Active
                  </ButtonLink>
                  <ButtonLink
                    type="tab"
                    icon="plug"
                    external
                    to="https://www.youtube.com/watch?v=h6fcK_fRYaI&ab_channel=Kurzgesagt%E2%80%93InaNutshell"
                  >
                    External
                  </ButtonLink>
                  <ButtonLink type="tab" disabled to={ONLY_DEV_DESIGN_SYSTEM_ROUTE}>
                    Disabled
                  </ButtonLink>
                </Block>
                <Typography className="mb-4" variant="subhead1">
                  Button Links with &#60;ButtonLink/&#62;
                </Typography>
                <Block>
                  <ButtonLink type="button" to={ONLY_DEV_DESIGN_SYSTEM_ROUTE}>
                    Internal
                  </ButtonLink>
                  <ButtonLink
                    type="button"
                    external
                    to="https://www.youtube.com/watch?v=h6fcK_fRYaI&ab_channel=Kurzgesagt%E2%80%93InaNutshell"
                  >
                    External
                  </ButtonLink>

                  <ButtonLink
                    type="button"
                    buttonProps={{ variant: 'tertiary', startIcon: 'bell' }}
                    to={ONLY_DEV_DESIGN_SYSTEM_ROUTE}
                  >
                    With Button Props
                  </ButtonLink>
                </Block>
                <Typography className="mb-4" variant="subhead1">
                  Simple links with &#60;a/&#62;
                </Typography>
                <Block>
                  <a href="https://main-app.staging.getlago.com/coupons"> Normal Link </a>
                </Block>
              </Container>
            ),
          },
          {
            title: 'Dialogs',
            link: DIALOG_TAB_URL,
            component: <DialogTest />,
          },
          {
            title: 'Drawers',
            link: DRAWER_TAB_URL,
            component: <DrawerTest />,
          },
          {
            title: 'Rich Text Editor',
            link: RICH_TEXT_EDITOR_TAB_URL,
            component: <EditorTest />,
          },
          // disabled simple tab
          {
            disabled: true,
            title: 'Disabled',
            link: '',
            component: <></>,
          },
        ]}
      />
    </>
  )
}

export default DesignSystem
