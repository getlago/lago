import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { useAiAgent } from '~/hooks/aiAgent/useAiAgent'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type PanelWrapperProps = {
  children: React.ReactNode
  title: string
  isBeta: boolean
  showBackButton?: boolean
  onBackButton?: () => void
  showHistoryButton?: boolean
  onShowHistory?: () => void
}

export const PanelWrapper = ({
  children,
  title,
  isBeta,
  showBackButton,
  onBackButton,
  showHistoryButton,
  onShowHistory,
}: PanelWrapperProps) => {
  const { closePanel } = useAiAgent()
  const { translate } = useInternationalization()

  return (
    <div>
      <div className="flex flex-row items-center justify-between gap-2 px-6 py-4 shadow-b">
        {!!showBackButton && (
          <Button size="medium" variant="quaternary" icon="arrow-left" onClick={onBackButton} />
        )}
        <div className="flex h-8 flex-1 items-center gap-2 truncate">
          <Typography variant="bodyHl" className="!truncate" color="grey700">
            {title}
          </Typography>
          {isBeta && (
            <Chip
              className="min-h-6 border-purple-200 bg-purple-100"
              color="infoMain"
              label={translate('text_65d8d71a640c5400917f8a13')}
            />
          )}
        </div>
        <div className="flex flex-row items-center gap-3">
          {showHistoryButton && (
            <Button size="medium" variant="quaternary" icon="history" onClick={onShowHistory} />
          )}
          <Button size="medium" variant="quaternary" icon="close" onClick={closePanel} />
        </div>
      </div>
      <div className="height-minus-nav flex flex-col justify-between overflow-y-auto">
        {children}
      </div>
    </div>
  )
}
