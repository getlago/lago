import { isMeaningfulPresentationValue } from '~/components/customers/usage/usageDetailsHelpers'
import { Chip } from '~/components/designSystem/Chip'

type BreakdownNameCellProps = {
  presentationBy: Record<string, unknown>
}

export const BreakdownNameCell = ({ presentationBy }: BreakdownNameCellProps) => (
  <div className="flex flex-wrap items-center gap-1 pl-4">
    {Object.entries(presentationBy)
      .filter(([, value]) => isMeaningfulPresentationValue(value))
      .map(([key, value]) => (
        <Chip key={key} label={String(value)} variant="captionCode" size="small" />
      ))}
  </div>
)
