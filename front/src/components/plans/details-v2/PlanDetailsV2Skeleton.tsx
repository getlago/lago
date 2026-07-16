import { Skeleton } from '~/components/designSystem/Skeleton'

const SIDEBAR_ROWS = [0, 1, 2, 3, 4, 5]
const CONTENT_SECTIONS = [0, 1, 2]

// Mirrors the two-column layout of PlanDetailsV2 so the separator (the sidebar's
// right border) stays visible and each column shows its own loading state.
export const PlanDetailsV2Skeleton = () => (
  <div className="flex gap-12">
    <nav
      className="sticky top-0 flex h-screen w-64 flex-col gap-4 border-r border-grey-300 pr-4 pt-4"
      aria-hidden="true"
    >
      {SIDEBAR_ROWS.map((row) => (
        <Skeleton key={`plan-details-v2-sidebar-skeleton-${row}`} variant="text" className="w-40" />
      ))}
    </nav>

    <div className="flex flex-1 flex-col">
      <div className="flex flex-col gap-12 py-12">
        {CONTENT_SECTIONS.map((section) => (
          <div key={`plan-details-v2-section-skeleton-${section}`} className="flex flex-col gap-4">
            <Skeleton variant="text" className="w-48" />
            <Skeleton variant="text" className="w-full" />
            <Skeleton variant="text" className="w-3/4" />
          </div>
        ))}
      </div>
    </div>
  </div>
)
