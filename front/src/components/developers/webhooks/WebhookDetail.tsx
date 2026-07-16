import { generatePath, matchPath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import {
  WEBHOOK_LOGS_ROUTE,
  WEBHOOK_ROUTE,
  WEBHOOKS_ROUTE,
} from '~/components/developers/devtoolsRoutes'
import { WebhookLogs } from '~/components/developers/webhooks/WebhookLogs'
import { WebhookOverview } from '~/components/developers/webhooks/WebhookOverview'
import { UPDATE_WEBHOOK_ROUTE, useLocation, useNavigate } from '~/core/router'
import { WebhookEndpointSignatureAlgoEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { useWebhookEndpoint } from '~/hooks/useWebhookEndpoint'
import { MenuPopper } from '~/styles'

import { useDeleteWebhook } from './useDeleteWebhook'

// Test ID constants
export const WEBHOOK_DETAIL_BACK_BUTTON_TEST_ID = 'webhook-detail-back-button'
export const WEBHOOK_DETAIL_TITLE_TEST_ID = 'webhook-detail-title'
export const WEBHOOK_DETAIL_SUBTITLE_TEST_ID = 'webhook-detail-subtitle'
export const WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID = 'webhook-detail-actions-button'
export const WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID = 'webhook-detail-edit-button'
export const WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID = 'webhook-detail-delete-button'

export const WebhookDetail = () => {
  const { webhookId = '' } = useParams<{ webhookId: string }>()
  const { strippedPathname: pathname } = useLocation()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { closePanel, setMainRouterUrl } = useDeveloperTool()
  const { openDialog: openDeleteDialog } = useDeleteWebhook()
  const { webhook, loading } = useWebhookEndpoint({ id: webhookId })

  const signatureLabel =
    webhook?.signatureAlgo === WebhookEndpointSignatureAlgoEnum.Jwt ? 'JWT' : 'HMAC'

  const webhookDetailTabs = [
    {
      title: translate('text_634687079be251fdb43833b7'),
      match: [WEBHOOK_ROUTE],
      component: (
        <WebhookOverview webhook={webhook} loading={loading} signatureLabel={signatureLabel} />
      ),
    },
    {
      title: translate('text_1746622271766kgqyug3llin'),
      match: [WEBHOOK_LOGS_ROUTE],
      component: <WebhookLogs webhookId={webhookId} />,
    },
  ]

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex items-start justify-between gap-4 p-4 shadow-b">
        <div className="flex flex-col items-start gap-2">
          <Button
            variant="inline"
            startIcon="arrow-left"
            onClick={() => navigate(WEBHOOKS_ROUTE)}
            data-test={WEBHOOK_DETAIL_BACK_BUTTON_TEST_ID}
          >
            {translate('text_1746622271766rvabvdcmo7v')}
          </Button>
          {loading ? (
            <>
              <Skeleton variant="text" className="w-60" textVariant="headline" />
              <Skeleton variant="text" className="w-40" textVariant="body" />
            </>
          ) : (
            <>
              <Typography variant="headline" data-test={WEBHOOK_DETAIL_TITLE_TEST_ID}>
                {webhook?.name || webhook?.webhookUrl}
              </Typography>
              {!!webhook?.name && (
                <Typography
                  variant="body"
                  color="grey600"
                  data-test={WEBHOOK_DETAIL_SUBTITLE_TEST_ID}
                >
                  {webhook.webhookUrl}
                </Typography>
              )}
            </>
          )}
        </div>

        <Popper
          PopperProps={{ placement: 'bottom-end' }}
          displayInDialog
          opener={
            <Button endIcon="chevron-down" data-test={WEBHOOK_DETAIL_ACTIONS_BUTTON_TEST_ID}>
              {translate('text_626162c62f790600f850b6fe')}
            </Button>
          }
        >
          {({ closePopper }) => (
            <MenuPopper>
              <Button
                fullWidth
                variant="quaternary"
                align="left"
                startIcon="pen"
                data-test={WEBHOOK_DETAIL_EDIT_BUTTON_TEST_ID}
                onClick={() => {
                  const path = generatePath(UPDATE_WEBHOOK_ROUTE, { webhookId })

                  setMainRouterUrl(path)
                  closePanel()
                  closePopper()
                }}
              >
                {translate('text_63aa15caab5b16980b21b0b8')}
              </Button>
              <Button
                fullWidth
                variant="quaternary"
                align="left"
                startIcon="trash"
                data-test={WEBHOOK_DETAIL_DELETE_BUTTON_TEST_ID}
                onClick={() => {
                  openDeleteDialog(webhookId, {
                    onSuccess: () => navigate(WEBHOOKS_ROUTE),
                  })
                  closePopper()
                }}
              >
                {translate('text_63aa15caab5b16980b21b0ba')}
              </Button>
            </MenuPopper>
          )}
        </Popper>
      </div>

      <NavigationTab
        className="px-4"
        tabPanelClassName="min-h-0 flex-1 overflow-auto"
        name="webhook-detail"
        managedBy={TabManagedBy.INDEX}
        loading={loading}
        currentTab={webhookDetailTabs.findIndex((tab) =>
          tab.match?.some((pattern) => matchPath(pattern, pathname)),
        )}
        tabs={webhookDetailTabs}
        onChange={(index) => {
          // Keep the MemoryRouter URL in sync with the active tab so that
          // "Copy Link" in DevtoolsView always copies the correct route.
          const tab = webhookDetailTabs[index]

          if (tab?.match?.includes(WEBHOOK_ROUTE)) {
            navigate(generatePath(WEBHOOK_ROUTE, { webhookId }))
          }
        }}
      />
    </div>
  )
}
