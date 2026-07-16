import { Icon, IconName } from 'lago-design-system'
import { generatePath } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { SettingsPaddedContainer } from '~/components/layouts/Settings'
import {
  BILLING_ENTITY_DUNNING_CAMPAIGNS_ROUTE,
  BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE,
  BILLING_ENTITY_GENERAL_ROUTE,
  BILLING_ENTITY_INVOICE_CUSTOM_SECTIONS_ROUTE,
  BILLING_ENTITY_INVOICE_SETTINGS_ROUTE,
  BILLING_ENTITY_TAXES_SETTINGS_ROUTE,
  useNavigate,
} from '~/core/router'
import { BillingEntity } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

type SettingsListItem = {
  id: string
  label: string
  sublabel: string
  actionLabel?: string
  path?: () => string
  icon: string
  onClick?: () => void
  className?: string
}

const SETTINGS_LIST_ITEMS: SettingsListItem[] = [
  {
    id: 'be-general',
    label: 'text_1742230191029o8hfgeebxl5',
    sublabel: 'text_17423672025283pz1d5alfnr',
    actionLabel: 'text_1742367266660i30uftbnwn5',
    path: () => BILLING_ENTITY_GENERAL_ROUTE,
    icon: 'target',
  },
  {
    id: 'be-email-scenarios',
    label: 'text_1742367202528mfhsv0f4fxq',
    sublabel: 'text_1742367202528ecx7ncm3ad2',
    actionLabel: 'text_1742367266660wav3un4ypug',
    path: () => BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE,
    icon: 'mail',
  },
  {
    id: 'be-invoice-settings',
    label: 'text_17423672025282dl7iozy1ru',
    sublabel: 'text_1742367202529pqbhrh9q8ju',
    actionLabel: 'text_1742367266660hztqo2bfrsh',
    path: () => BILLING_ENTITY_INVOICE_SETTINGS_ROUTE,
    icon: 'document',
  },
  {
    id: 'be-invoice-custom-sections',
    label: 'text_1749024634192ov41w9fp6r2',
    sublabel: 'text_17490246341929tjtb5ocz7l',
    actionLabel: 'text_17490246341928pjk45tv8vy',
    path: () => BILLING_ENTITY_INVOICE_CUSTOM_SECTIONS_ROUTE,
    icon: 'document',
  },
  {
    id: 'be-dunning-campaigns',
    label: 'text_1742367202528ti8wj2iwa96',
    sublabel: 'text_1742367202528vgpo1ojm11b',
    actionLabel: 'text_1742367266660e7qgs4vaf1i',
    path: () => BILLING_ENTITY_DUNNING_CAMPAIGNS_ROUTE,
    icon: 'push',
  },
  {
    id: 'be-taxes',
    label: 'text_1742367202529opm80ylmp75',
    sublabel: 'text_174236720252957g5kmpz7vg',
    actionLabel: 'text_1742367266660hv5m1bt63nw',
    path: () => BILLING_ENTITY_TAXES_SETTINGS_ROUTE,
    icon: 'percentage',
  },
]

type BillingEntityMainProps = {
  billingEntity: BillingEntity
}

type ItemProps = {
  item: SettingsListItem
  billingEntityCode: string
}

const Item = ({ item, billingEntityCode }: ItemProps) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const onClick = () => {
    if (item.path) {
      navigate(
        generatePath(item.path(), {
          billingEntityCode,
        }),
      )
    }

    if (item.onClick) {
      item.onClick()
    }
  }

  return (
    <>
      {/* eslint-disable-next-line jsx-a11y/no-static-element-interactions */}
      <div
        className={tw('flex cursor-pointer gap-4 pb-8 shadow-b', item.className)}
        onClick={() => onClick()}
        onKeyDown={() => {}}
      >
        <Avatar size="big" variant="connector">
          <Icon size="medium" name={item.icon as IconName} color="dark" />
        </Avatar>
        <div className="grow">
          <Typography variant="bodyHl" color="grey700">
            {translate(item.label)}
          </Typography>
          <Typography variant="caption" color="grey600">
            {translate(item.sublabel)}
          </Typography>
        </div>

        {(item.path || item.onClick) && (
          <Tooltip placement="top-end" title={item.actionLabel ? translate(item.actionLabel) : ''}>
            <Button icon="chevron-right" variant="quaternary" onClick={() => onClick()} />
          </Tooltip>
        )}
      </div>
    </>
  )
}

const BillingEntityMain = ({ billingEntity }: BillingEntityMainProps) => {
  const { translate } = useInternationalization()

  return (
    <SettingsPaddedContainer className="gap-0">
      <Typography variant="subhead1" color="grey700">
        {translate('text_1742367266660b7aw6idpgux')}
      </Typography>

      <div className="mt-8 flex flex-col gap-8">
        {SETTINGS_LIST_ITEMS.map((item) => (
          <Item key={item.id} item={item} billingEntityCode={billingEntity?.code} />
        ))}
      </div>

      <Typography variant="subhead1" color="grey700" className="mt-10">
        {translate('text_1742367202529va1w02u4jex')}
      </Typography>

      <div className="mt-4 flex flex-col gap-6">
        <Item
          item={{
            id: 'billing-entity-delete',
            className: 'shadow-b-0',
            label: 'text_1742367266659ihskmbc8ugz',
            sublabel: 'text_1742367266660brmeya6gbcn',
            icon: 'trash',
          }}
          billingEntityCode={billingEntity?.code}
        />
      </div>
    </SettingsPaddedContainer>
  )
}

export default BillingEntityMain
