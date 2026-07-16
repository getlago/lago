import { gql, useApolloClient } from '@apollo/client'
import ClickAwayListener from '@mui/material/ClickAwayListener'
import { useEffect, useRef, useState } from 'react'
import { Location, Outlet } from 'react-router-dom'

import { Spinner } from '~/components/designSystem/Spinner'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderProvider } from '~/components/MainHeader/MainHeaderContext'
import { useLocation } from '~/core/router'
import { useSideNavInfosQuery } from '~/generated/graphql'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { NavLayout } from '~/layouts/NavLayout'

import { BottomNavSection } from './BottomNavSection'
import { MainNavMenuSections } from './MainNavMenuSections'
import { OrganizationSwitcher } from './OrganizationSwitcher'

export const MAIN_NAV_LAYOUT_WRAPPER_TEST_ID = 'main-nav-layout-wrapper'
export const MAIN_NAV_LAYOUT_SPINNER_TEST_ID = 'main-nav-layout-spinner'
export const MAIN_NAV_LAYOUT_CONTENT_TEST_ID = 'main-nav-layout-content-wrapper'

gql`
  query SideNavInfos {
    currentVersion {
      githubUrl
      number
    }
  }
`

const MainNavLayout = () => {
  const location = useLocation()
  const client = useApolloClient()
  const [open, setOpen] = useState(false)

  const { currentUser, loading: currentUserLoading } = useCurrentUser()
  const { organization, loading: currentOrganizationLoading } = useOrganizationInfos()
  const { data, loading: versionLoading } = useSideNavInfosQuery({
    errorPolicy: 'all',
    notifyOnNetworkStatusChange: true,
  })

  const { pathname, state } = location as Location & { state: { disableScrollTop?: boolean } }
  const contentRef = useRef<HTMLDivElement>(null)
  const isLoading = currentOrganizationLoading || currentUserLoading || versionLoading

  useEffect(() => {
    // Avoid weird scroll behavior on navigation
    if (!contentRef.current || state?.disableScrollTop) return
    contentRef.current?.scrollTo(0, 0)
  }, [pathname, contentRef, state?.disableScrollTop])

  const handleNavItemClick = () => setOpen(false)

  return (
    <div data-test={MAIN_NAV_LAYOUT_WRAPPER_TEST_ID}>
      <NavLayout.NavWrapper>
        <NavLayout.NavBurgerButton onClick={() => setOpen((prev) => !prev)} />

        <ClickAwayListener
          onClickAway={() => {
            if (open) setOpen(false)
          }}
        >
          <NavLayout.Nav isOpen={open}>
            <OrganizationSwitcher
              client={client}
              currentUser={currentUser}
              organization={organization}
              currentVersion={data?.currentVersion}
              isLoading={isLoading}
              isVersionLoading={versionLoading}
            />

            <MainNavMenuSections isLoading={isLoading} onItemClick={handleNavItemClick} />

            <BottomNavSection isLoading={isLoading} onItemClick={handleNavItemClick} />
          </NavLayout.Nav>
        </ClickAwayListener>

        <MainHeaderProvider>
          <NavLayout.ContentWrapper ref={contentRef} data-test={MAIN_NAV_LAYOUT_CONTENT_TEST_ID}>
            {isLoading && <Spinner data-test={MAIN_NAV_LAYOUT_SPINNER_TEST_ID} />}
            {!isLoading && (
              <>
                <MainHeader />
                <Outlet />
              </>
            )}
          </NavLayout.ContentWrapper>
        </MainHeaderProvider>
      </NavLayout.NavWrapper>
    </div>
  )
}

export default MainNavLayout
