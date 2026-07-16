import { ReactNode, Suspense, useEffect } from 'react'
import { RouteObject, useRoutes } from 'react-router-dom'

import { Spinner } from '~/components/designSystem/Spinner'
import { DEVTOOL_ROUTE } from '~/components/developers/devtoolsRoutes'
import { drawerStack } from '~/components/drawers/drawerStack'
import { CustomRouteObject, routes, useLocation, useNavigate } from '~/core/router'
import { NEVER_SLUG_PREFIXES } from '~/core/router/slugPrefixes'
import { useIsAuthenticated } from '~/hooks/auth/useIsAuthenticated'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { DEVTOOL_TAB_PARAMS, useDeveloperTool } from '~/hooks/useDeveloperTool'

interface PageWrapperProps {
  routeConfig: CustomRouteObject
  children: ReactNode
}

const PageWrapper = ({ children, routeConfig }: PageWrapperProps) => {
  const location = useLocation()
  const { onRouteEnter } = useLocationHistory()

  useEffect(() => {
    onRouteEnter(routeConfig, location)
  }, [location, routeConfig, onRouteEnter])

  // Redirect to '/' and open devtools if path starts with DEVTOOL_ROUTE
  useEffect(() => {
    if (location.pathname.startsWith(DEVTOOL_ROUTE)) {
      // Set the devtool param in the URL for the homepage
      const url = new URL(window.location.href)

      url.pathname = '/'
      // URLSearchParams.set() handles encoding automatically, so we don't need encodeURIComponent
      url.searchParams.set(DEVTOOL_TAB_PARAMS, location.pathname)
      window.location.replace(url.toString())
    }
  }, [location])

  if (location.pathname.startsWith(DEVTOOL_ROUTE)) {
    // Prevent rendering anything while redirecting
    return null
  }

  return <>{children}</>
}

const routesFormatter: (routesToFormat: CustomRouteObject[], loggedIn: boolean) => RouteObject[] = (
  routesToFormat,
  loggedIn,
) => {
  return routesToFormat.reduce<RouteObject[]>((acc, route) => {
    const routeConfig = {
      element: (
        <PageWrapper routeConfig={route}>
          <Suspense fallback={<Spinner />}>{route.element}</Suspense>
        </PageWrapper>
      ),
      ...(route?.children ? { children: routesFormatter(route.children, loggedIn) } : {}),
    }

    if (route.index) {
      acc.push({
        index: true,
        ...routeConfig,
      } as RouteObject)
    } else if (!route.path) {
      acc.push(routeConfig)
    } else if (typeof route.path === 'string') {
      acc.push({
        path: route.path,
        ...routeConfig,
      })
    } else {
      ;(route.path as string[]).map((singlePath) => {
        acc.push({
          path: singlePath,
          ...routeConfig,
        })
      })
    }

    return acc
  }, [])
}

export const RouteWrapper = () => {
  const { isAuthenticated } = useIsAuthenticated()
  const location = useLocation()
  const navigate = useNavigate()
  const { mainRouterUrl, setMainRouterUrl } = useDeveloperTool()

  // Clear all open drawers on browser navigation (back/forward buttons)
  useEffect(() => {
    drawerStack.clearAll()
  }, [location])

  // Bridge devtools MemoryRouter → BrowserRouter without a page reload.
  // RouteWrapper sits outside `:organizationSlug`, so the slug-aware
  // `useNavigate` wrapper has no slug to prepend. We derive it from the
  // first segment of the current URL (authoritative per-tab) and pass
  // `skipSlugPrepend: true`. Public paths are skipped via
  // `NEVER_SLUG_PREFIXES`.
  useEffect(() => {
    if (!mainRouterUrl) return

    const firstSegment = location.pathname.split('/')[1] ?? ''
    const onPublicPath = NEVER_SLUG_PREFIXES.some((prefix) => location.pathname.startsWith(prefix))
    const slug = !onPublicPath && firstSegment ? firstSegment : undefined
    const target = slug ? `/${slug}${mainRouterUrl}` : mainRouterUrl

    navigate(target, { skipSlugPrepend: true })
    setMainRouterUrl('')
  }, [mainRouterUrl, location.pathname, navigate, setMainRouterUrl])

  const formattedRoutes = routesFormatter(routes, isAuthenticated)

  return useRoutes(formattedRoutes)
}
