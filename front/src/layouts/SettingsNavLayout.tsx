import ClickAwayListener from '@mui/material/ClickAwayListener'
import { useEffect, useRef, useState } from 'react'
import { generatePath, Location, Outlet, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { VerticalMenu, VerticalMenuSectionTitle } from '~/components/designSystem/VerticalMenu'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderProvider } from '~/components/MainHeader/MainHeaderContext'
import { IntegrationsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  BILLING_ENTITY_CREATE_ROUTE,
  BILLING_ENTITY_ROUTE,
  BILLING_ENTITY_UPDATE_ROUTE,
  CREATE_DUNNING_ROUTE,
  CREATE_INVOICE_CUSTOM_SECTION,
  CREATE_PRICING_UNIT,
  CREATE_TAX_ROUTE,
  DUNNINGS_SETTINGS_ROUTE,
  EDIT_INVOICE_CUSTOM_SECTION,
  EDIT_PRICING_UNIT,
  FULL_INTEGRATIONS_ROUTE,
  FULL_INTEGRATIONS_ROUTE_ID,
  GENERAL_SETTINGS_ROUTE,
  HOME_ROUTE,
  INTEGRATIONS_ROUTE,
  INVOICE_SETTINGS_ROUTE,
  OKTA_AUTHENTICATION_ROUTE,
  ROLE_CREATE_ROUTE,
  ROLE_DETAILS_ROUTE,
  ROLE_EDIT_ROUTE,
  settingRoutes,
  TAXES_SETTINGS_ROUTE,
  TEAM_AND_SECURITY_GROUP_ROUTE,
  TEAM_AND_SECURITY_ROOT_ROUTE,
  TEAM_AND_SECURITY_TAB_ROUTE,
  UPDATE_DUNNING_ROUTE,
  UPDATE_TAX_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { useGetBillingEntitiesQuery } from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { TMembershipPermissions, usePermissions } from '~/hooks/usePermissions'

import { NavLayout } from './NavLayout'

// Test IDs
export const SETTINGS_NAV_BURGER_BUTTON_TEST_ID = 'settings-nav-burger-button'
export const SETTINGS_NAV_BACK_BUTTON_TEST_ID = 'settings-nav-back-button'
export const SETTINGS_NAV_CREATE_BILLING_ENTITY_BUTTON_TEST_ID =
  'settings-nav-create-billing-entity-button'
export const SETTINGS_NAV_BILLING_ENTITY_ITEM_TEST_ID = 'settings-nav-billing-entity-item'

const generateTabs = ({
  translate,
  hasPermissions,
}: {
  translate: TranslateFunc
  hasPermissions: (permissionsToCheck: Array<keyof TMembershipPermissions>) => boolean
}) => [
  {
    title: translate('text_1776867582729i8hvt0ot0wl'),
    link: GENERAL_SETTINGS_ROUTE,
    match: [GENERAL_SETTINGS_ROUTE],
    hidden: !hasPermissions(['organizationView']),
  },
  {
    title: translate('text_62b1edddbf5f461ab9712733'),
    link: generatePath(INTEGRATIONS_ROUTE, {
      integrationGroup: IntegrationsTabsOptionsEnum.Lago,
    }),
    match: [INTEGRATIONS_ROUTE, FULL_INTEGRATIONS_ROUTE, FULL_INTEGRATIONS_ROUTE_ID],
    hidden: !hasPermissions(['organizationIntegrationsView']),
  },
  {
    title: translate('text_177073440645951fhlh2ofdc'),
    link: TEAM_AND_SECURITY_ROOT_ROUTE,
    match: [
      TEAM_AND_SECURITY_ROOT_ROUTE,
      TEAM_AND_SECURITY_GROUP_ROUTE,
      TEAM_AND_SECURITY_TAB_ROUTE,
      ROLE_DETAILS_ROUTE,
      OKTA_AUTHENTICATION_ROUTE,
    ],
    hidden:
      !hasPermissions(['organizationMembersView']) &&
      !hasPermissions(['rolesView']) &&
      !hasPermissions(['authenticationMethodsView']) &&
      !hasPermissions(['securityLogsView']),
  },
  {
    title: translate('text_63ac86d797f728a87b2f9f85'),
    link: INVOICE_SETTINGS_ROUTE,
    hidden: !hasPermissions(['organizationInvoicesView']),
  },
  {
    title: translate('text_17285747264958mqbtws3em8'),
    link: DUNNINGS_SETTINGS_ROUTE,
    match: [DUNNINGS_SETTINGS_ROUTE],
    hidden: !hasPermissions(['dunningCampaignsView']),
  },
  {
    title: translate('text_645bb193927b375079d28a8f'),
    link: TAXES_SETTINGS_ROUTE,
    match: [TAXES_SETTINGS_ROUTE],
    hidden: !hasPermissions(['organizationTaxesView']),
  },
]

const isEntityActive = (code: string, current: string) => code === current

const SettingsNavLayout = () => {
  const location = useLocation()
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { hasPermissions } = usePermissions()
  const { billingEntityCode } = useParams()
  const navigate = useNavigate()
  const { organization: { canCreateBillingEntity } = {} } = useOrganizationInfos()
  const contentRef = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)

  const { data: billingEntities, loading: billingEntitiesLoading } = useGetBillingEntitiesQuery({})

  const premiumWarningDialog = usePremiumWarningDialog()

  const TABS_ORGANIZATION = generateTabs({
    translate,
    hasPermissions,
  })

  const { pathname, state } = location as Location & { state: { disableScrollTop?: boolean } }

  useEffect(() => {
    // Avoid weird scroll behavior on navigation
    if (!contentRef.current || state?.disableScrollTop) return
    contentRef.current?.scrollTo(0, 0)
  }, [pathname, contentRef, state?.disableScrollTop])

  const routesToExcludeFromBackRedirection = settingRoutes[0].children?.reduce<string[]>(
    (acc, cur) => {
      if (!cur.path) return acc

      if (Array.isArray(cur.path)) {
        acc.push(...cur.path)
      } else {
        acc.push(cur.path)
      }
      return acc
    },
    [
      CREATE_TAX_ROUTE,
      UPDATE_TAX_ROUTE,
      CREATE_DUNNING_ROUTE,
      UPDATE_DUNNING_ROUTE,
      CREATE_INVOICE_CUSTOM_SECTION,
      EDIT_INVOICE_CUSTOM_SECTION,
      BILLING_ENTITY_CREATE_ROUTE,
      BILLING_ENTITY_UPDATE_ROUTE,
      CREATE_PRICING_UNIT,
      EDIT_PRICING_UNIT,
      ROLE_CREATE_ROUTE,
      ROLE_EDIT_ROUTE,
    ],
  )

  return (
    <NavLayout.NavWrapper>
      <NavLayout.NavBurgerButton
        data-test={SETTINGS_NAV_BURGER_BUTTON_TEST_ID}
        onClick={() => setOpen((prev) => !prev)}
      />
      <ClickAwayListener
        onClickAway={() => {
          if (open) setOpen(false)
        }}
      >
        <NavLayout.Nav isOpen={open}>
          <NavLayout.NavStickyElementContainer>
            <Button
              data-test={SETTINGS_NAV_BACK_BUTTON_TEST_ID}
              variant="quaternary"
              startIcon="arrow-left"
              size="small"
              onClick={() => {
                goBack(HOME_ROUTE, {
                  exclude: routesToExcludeFromBackRedirection,
                })
              }}
            >
              <Typography variant="caption" color="grey600" noWrap>
                {translate('text_65df4fc6314ffd006ce0a537')}
              </Typography>
            </Button>
          </NavLayout.NavStickyElementContainer>

          <NavLayout.NavSectionGroup>
            <NavLayout.NavSection>
              <VerticalMenuSectionTitle
                title={translate('text_1742230191028y9ffl7i1dhe')}
                icon="company"
              />

              <div className="flex flex-col gap-1">
                {billingEntitiesLoading && <Skeleton className="w-full px-3" variant="text" />}

                {!billingEntitiesLoading &&
                  billingEntities?.billingEntities?.collection?.map((entity, index) => (
                    <ButtonLink
                      className="[&_button]:rounded-lg"
                      key={`${index}-${entity.code}`}
                      title={entity.name}
                      to={generatePath(BILLING_ENTITY_ROUTE, {
                        billingEntityCode: entity.code,
                      })}
                      type="tab"
                      active={isEntityActive(entity.code, billingEntityCode || '')}
                      canBeClickedOnActive={true}
                      data-test={`${SETTINGS_NAV_BILLING_ENTITY_ITEM_TEST_ID}-${entity.code}`}
                      buttonProps={{
                        size: 'small',
                      }}
                    >
                      <Typography variant="caption" color="inherit" noWrap>
                        {entity.name}
                      </Typography>
                    </ButtonLink>
                  ))}

                <div className="px-3 py-1">
                  <Button
                    data-test={SETTINGS_NAV_CREATE_BILLING_ENTITY_BUTTON_TEST_ID}
                    variant="inline"
                    align="left"
                    size="small"
                    startIcon="plus"
                    endIcon={!canCreateBillingEntity ? 'sparkles' : undefined}
                    onClick={() => {
                      if (canCreateBillingEntity) {
                        navigate(generatePath(BILLING_ENTITY_CREATE_ROUTE))
                      } else {
                        premiumWarningDialog.open()
                      }
                    }}
                  >
                    {translate('text_1742367266660p3a701mnvli')}
                  </Button>
                </div>
              </div>
            </NavLayout.NavSection>

            <NavLayout.NavSection>
              <VerticalMenuSectionTitle
                title={translate('text_1742230191028ts64cxrgwdj')}
                icon="globe"
              />

              <VerticalMenu
                onClick={() => {
                  setOpen(false)
                }}
                tabs={TABS_ORGANIZATION}
              />
            </NavLayout.NavSection>
          </NavLayout.NavSectionGroup>
        </NavLayout.Nav>
      </ClickAwayListener>

      <MainHeaderProvider>
        <NavLayout.ContentWrapper ref={contentRef}>
          <MainHeader />
          <Outlet />
        </NavLayout.ContentWrapper>
      </MainHeaderProvider>
    </NavLayout.NavWrapper>
  )
}

export default SettingsNavLayout
