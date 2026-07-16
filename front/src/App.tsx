import { ApolloClient, ApolloProvider, NormalizedCacheObject } from '@apollo/client'
import { loadDevMessages, loadErrorMessages } from '@apollo/client/dev'
import { Provider as NiceModalProvider } from '@ebay/nice-modal-react'
import { StyledEngineProvider, ThemeProvider } from '@mui/material/styles'
import { captureException } from '@sentry/react'
import { useEffect, useState } from 'react'
import { Panel, PanelGroup } from 'react-resizable-panels'
import { BrowserRouter, MemoryRouter } from 'react-router-dom'

import { AiAgent } from '~/components/aiAgent/AiAgent'
import { Spinner } from '~/components/designSystem/Spinner'
import { ToastContainer } from '~/components/designSystem/Toasts/ToastContainer'
import { DevtoolsErrorBoundary } from '~/components/developers/DevtoolsErrorBoundary'
import { DEVTOOL_ROUTE } from '~/components/developers/devtoolsRoutes'
import { DevtoolsView } from '~/components/developers/DevtoolsView'
import { ErrorBoundary } from '~/components/ErrorBoundary'
import { RouteWrapper } from '~/components/RouteWrapper'
import { UserIdentifier } from '~/components/UserIdentifier'
import {
  envGlobalVar,
  initializeApolloClient,
  initializeTranslations,
  logOut,
  setAuthErrorHandler,
} from '~/core/apolloClient'
import { AppEnvEnum } from '~/core/constants/globalTypes'
import '~/core/overlays/registeredDialogs'
import { initializeYup } from '~/formValidation/initializeYup'
import { AiAgentProvider } from '~/hooks/aiAgent/useAiAgent'
import { DeveloperToolProvider, DEVTOOL_AUTO_SAVE_ID } from '~/hooks/useDeveloperTool'
import { QuotePdfProvider } from '~/pages/quotes/common/QuotePdfProvider'
import Logo from '~/public/images/logo/lago-logo-grey.svg'
import { theme } from '~/styles'

const App = () => {
  const [client, setClient] = useState<ApolloClient<NormalizedCacheObject> | null>(null)
  const [servicesReady, setServicesReady] = useState(false)
  const [initializationError, setInitializationError] = useState(false)
  const { appEnv } = envGlobalVar()

  useEffect(() => {
    async function initializeServices() {
      try {
        // Initialize synchronous services first
        initializeYup()

        // Initialize async services in parallel
        const [apolloClient] = await Promise.all([
          initializeApolloClient(),
          initializeTranslations(),
        ])

        // Set up auth error handler with the client instance
        setAuthErrorHandler(async () => {
          await logOut(apolloClient)
        })

        setClient(apolloClient)
        setServicesReady(true)
      } catch (err) {
        // Report service initialization errors to Sentry
        captureException(err, {
          tags: {
            errorType: 'ServiceInitializationError',
            component: 'App',
          },
        })

        // eslint-disable-next-line no-console
        console.error('Failed to initialize services:', err)
        setInitializationError(true)
      }
    }

    initializeServices()
  }, [])

  // Adds explicit apollo messages only in a dev environment
  if (appEnv === AppEnvEnum.development) {
    loadDevMessages()
    loadErrorMessages()
  }

  if (initializationError) {
    // Show error state if initialization failed
    // Note that translations and design system are not available in this case
    return (
      <div className="flex h-screen w-screen flex-col items-center justify-center gap-4">
        <Logo width="80px" />
        <div className="flex flex-col gap-1 text-center">
          <h2 className="text-lg font-semibold text-grey-700">Failed to initialize application</h2>
          <p className="text-sm text-grey-600">
            Please refresh the page or contact us if the error persists.
          </p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="mt-4 rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Reload
          </button>
        </div>
      </div>
    )
  }

  // Show loading spinner while services are initializing
  if (!client || !servicesReady) {
    return <Spinner />
  }

  return (
    <ApolloProvider client={client}>
      <StyledEngineProvider injectFirst>
        <ThemeProvider theme={theme}>
          <ErrorBoundary>
            <DeveloperToolProvider>
              <AiAgentProvider>
                <NiceModalProvider>
                  <QuotePdfProvider>
                    <PanelGroup direction="vertical" autoSaveId={DEVTOOL_AUTO_SAVE_ID}>
                      <BrowserRouter basename="/">
                        <Panel id="app-panel-group">
                          <PanelGroup direction="horizontal">
                            <Panel id="app-panel">
                              <div className="h-full overflow-auto" data-app-wrapper>
                                <RouteWrapper />
                              </div>
                            </Panel>
                            <AiAgent />
                          </PanelGroup>
                        </Panel>
                      </BrowserRouter>
                      <MemoryRouter initialEntries={[DEVTOOL_ROUTE]}>
                        <DevtoolsErrorBoundary>
                          <DevtoolsView />
                        </DevtoolsErrorBoundary>
                      </MemoryRouter>
                    </PanelGroup>
                  </QuotePdfProvider>
                </NiceModalProvider>
              </AiAgentProvider>
            </DeveloperToolProvider>
          </ErrorBoundary>
          <UserIdentifier />
          <ToastContainer />
        </ThemeProvider>
      </StyledEngineProvider>
    </ApolloProvider>
  )
}

export default App
