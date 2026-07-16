import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import EmptyImage from '~/public/images/maneki/empty.svg'

export const QUOTE_ACTIVITY_LOGS_CONTAINER_TEST_ID = 'quote-activity-logs-container'

const QuoteDetailsActivityLogs = (): JSX.Element => {
  const { translate } = useInternationalization()

  return (
    <div
      className="w-full px-4 pb-20 pt-6 md:px-12"
      data-test={QUOTE_ACTIVITY_LOGS_CONTAINER_TEST_ID}
    >
      <GenericPlaceholder
        title={translate('text_1775749367376kjpj8v9d3a6')}
        subtitle={translate('text_17757493673761ovrgfrw8xo')}
        image={<EmptyImage width="136" height="104" />}
      />
    </div>
  )
}

export default QuoteDetailsActivityLogs
