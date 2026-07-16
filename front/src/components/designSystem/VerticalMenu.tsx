import { Icon, IconName } from 'lago-design-system'
import _omit from 'lodash/omit'
import { ReactNode } from 'react'
import { matchPath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { useLocation } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { ButtonLink, ButtonLinkTabProps } from './ButtonLink'

interface VerticalMenuProps extends Omit<ButtonLinkTabProps, 'to' | 'type' | 'children'> {
  link?: string
  onAction?: () => void
  match?: string[]
  hidden?: boolean
  title?: string
  component?: ReactNode
  beta?: boolean
  extraComponent?: React.ReactElement
}

interface VerticalMenusProps {
  name?: string
  tabs: VerticalMenuProps[]
  loading?: boolean
  loadingComponent?: ReactNode
  component?: ReactNode
  children?: ReactNode
  onClick?: (tab: VerticalMenuProps) => void
}

export const VerticalMenu = ({
  name = '',
  tabs,
  loading,
  loadingComponent,
  children,
  onClick,
  ...props
}: VerticalMenusProps) => {
  const { translate } = useInternationalization()
  const { strippedPathname: pathname } = useLocation()
  const activeTab = tabs.find(
    (tab) => tab.link === pathname || !!tab.match?.find((path) => !!matchPath(path, pathname)),
  )

  return (
    <div className="flex w-full flex-col overflow-visible" {...props}>
      {!loading && (
        <div className="flex w-full flex-1 flex-col gap-1 overflow-visible">
          {tabs.map((tab, i) => {
            const { link, hidden, title, beta, external, onAction, extraComponent, ...tabProps } =
              tab

            if (hidden) return null

            if (link) {
              return (
                <ButtonLink
                  className="[&_button]:rounded-lg"
                  external={external}
                  title={title}
                  key={`${i}-${name}-${link}`}
                  to={link}
                  type="tab"
                  active={link === activeTab?.link}
                  onClick={!!onClick ? () => onClick(tab) : undefined}
                  buttonProps={{
                    size: 'small',
                  }}
                  {..._omit(tabProps, ['component', 'match'])}
                >
                  <div className="flex w-full flex-row items-center justify-between">
                    <div className="flex items-baseline gap-2">
                      <Typography variant="caption" color="inherit" noWrap>
                        {title}
                      </Typography>
                      {!!beta && (
                        <Chip size="small" label={translate('text_65d8d71a640c5400917f8a13')} />
                      )}
                    </div>
                    {!!external && <Icon name="outside" />}
                    {!!extraComponent && extraComponent}
                  </div>
                </ButtonLink>
              )
            } else if (onAction) {
              return (
                <Button
                  key={`${i}-${name}-${link}`}
                  variant="quaternary"
                  startIcon={tabProps.icon}
                  onClick={onAction}
                  size="small"
                >
                  <div className="flex w-full flex-row items-center justify-between">
                    <div className="flex items-baseline gap-2">
                      <Typography variant="caption" color="inherit" noWrap>
                        {title}
                      </Typography>
                      {!!beta && (
                        <Chip size="small" label={translate('text_65d8d71a640c5400917f8a13')} />
                      )}
                    </div>
                    {!!external && <Icon name="outside" />}
                    {!!extraComponent && extraComponent}
                  </div>
                </Button>
              )
            }
          })}
        </div>
      )}
      {loading && loadingComponent}
      {loading && !loadingComponent && (
        <div className="m-auto flex h-40 w-full items-center justify-center">
          <Icon name="processing" color="info" size="large" animation="spin" />
        </div>
      )}
      {!loading && (activeTab?.component || children)}
    </div>
  )
}

export const VerticalMenuSectionTitle = ({
  title,
  icon,
  loading,
}: {
  title: string
  icon?: IconName
  loading?: boolean
}) => {
  if (loading) return <Skeleton variant="text" className="w-25" />

  return (
    <div className="flex items-center gap-2 px-3 py-1">
      {icon && <Icon name={icon} size="small" />}

      <Typography variant="noteHl" color="grey500">
        {title}
      </Typography>
    </div>
  )
}
