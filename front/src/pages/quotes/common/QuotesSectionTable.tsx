import { IconName } from 'lago-design-system'

import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { useInternationalization } from '~/hooks/core/useInternationalization'

interface QuotesSectionTableProps<T> {
  name: string
  data: T[]
  isLoading: boolean
  hasError: boolean
  metadata: { currentPage: number; totalPages: number } | undefined
  fetchMore: ((opts: { variables: { page: number } }) => Promise<unknown>) | undefined
  columns: Array<TableColumn<T>>
  emptyState: { title: string; subtitle: string }
  getActions?: (row: T) => Array<{ icon: IconName; label: string; onAction: () => void }>
  onRowActionLink?: (row: T) => string
  className?: string
  containerClassName?: string
}

export const QuotesSectionTable = <T extends { id: string }>({
  name,
  data,
  isLoading,
  hasError,
  metadata,
  fetchMore,
  columns,
  emptyState,
  getActions,
  onRowActionLink,
  className,
  containerClassName,
}: QuotesSectionTableProps<T>): JSX.Element => {
  const { translate } = useInternationalization()

  const onBottom = () => {
    const { currentPage = 0, totalPages = 0 } = metadata || {}

    currentPage < totalPages && !isLoading && fetchMore?.({ variables: { page: currentPage + 1 } })
  }

  return (
    <DetailsPage.Container className={className}>
      <InfiniteScroll onBottom={onBottom}>
        <Table
          name={name}
          containerClassName={containerClassName}
          data={data}
          isLoading={isLoading}
          hasError={hasError}
          containerSize={0}
          columns={columns}
          onRowActionLink={onRowActionLink}
          actionColumnTooltip={
            getActions ? () => translate('text_1776414006125pcxcyeblul7') : undefined
          }
          actionColumn={
            getActions
              ? (row) => {
                  const actions = getActions(row)

                  if (actions.length === 0) return null

                  return actions.map(({ icon, label, onAction }) => ({
                    startIcon: icon,
                    title: label,
                    onAction: () => onAction(),
                  }))
                }
              : undefined
          }
          placeholder={{
            emptyState: {
              title: emptyState.title,
              subtitle: emptyState.subtitle,
            },
          }}
        />
      </InfiniteScroll>
    </DetailsPage.Container>
  )
}
