import { Icon, IconName } from 'lago-design-system'

import { AiBadge } from '~/components/designSystem/AiBadge'
import { Button } from '~/components/designSystem/Button'
import { DOCUMENTATION_URL, FEATURE_REQUESTS_URL } from '~/core/constants/externalUrls'
import { AIPanelEnum, useAiAgent } from '~/hooks/aiAgent/useAiAgent'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type NavigationBarProps = {
  hasAccessToAiAgent: boolean
}

export const NavigationBar = ({ hasAccessToAiAgent }: NavigationBarProps) => {
  const { togglePanel, currentPanelOpened } = useAiAgent()
  const { translate } = useInternationalization()

  const getCurrentPanelVariant = (panel: AIPanelEnum) =>
    currentPanelOpened === panel ? 'secondary' : 'quaternary'

  const externalLinkButtons = [
    {
      title: translate('text_63fdd3e4076c80ecf4136f33'),
      icon: 'bulb',
      link: FEATURE_REQUESTS_URL,
      external: true,
    },
    {
      title: translate('text_6295e58352f39200d902b01c'),
      icon: 'book',
      link: DOCUMENTATION_URL,
      external: true,
    },
  ].map((button, index) => (
    <Button
      size="small"
      variant="quaternary"
      onClick={() => window.open(button.link, '_blank')}
      key={`navigation-bar-button-${index}`}
    >
      <div className="flex flex-row items-center gap-2">
        <Icon className="-rotate-90" name={button.icon as IconName} size="medium" color="dark" />

        <div>{button.title}</div>
      </div>
    </Button>
  ))

  return (
    <div className="flex flex-row gap-2 p-2">
      {hasAccessToAiAgent && (
        <Button
          size="small"
          variant={getCurrentPanelVariant(AIPanelEnum.ai)}
          onClick={() => togglePanel(AIPanelEnum.ai)}
        >
          <div className="flex flex-row items-center gap-2">
            {currentPanelOpened === AIPanelEnum.ai ? (
              <Icon name="sparkles-base" size="small" color="primary" />
            ) : (
              <AiBadge className="bg-none p-0" />
            )}
            <div>{translate('text_175741722585199myqwj6vyw')}</div>
          </div>
        </Button>
      )}

      {externalLinkButtons}
    </div>
  )
}
