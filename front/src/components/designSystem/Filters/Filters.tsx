import { Button } from '~/components/designSystem/Button'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { ActiveFiltersList } from './ActiveFiltersList'
import { FiltersPanelPopper } from './FiltersPanelPopper'
import { useFilters } from './useFilters'

interface FiltersProps {
  className?: string
}

export const Filters = ({ className }: FiltersProps) => {
  const { translate } = useInternationalization()

  const { hasAppliedFilters, resetFilters } = useFilters()

  return (
    <div className={tw('flex w-full flex-wrap items-center gap-3 overflow-y-auto', className)}>
      <FiltersPanelPopper />
      <ActiveFiltersList />

      {hasAppliedFilters && (
        <Button variant="quaternary" size="small" onClick={resetFilters}>
          {translate('text_66ab4886cc65a6006ee7258c')}
        </Button>
      )}
    </div>
  )
}
