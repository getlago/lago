import { Skeleton } from '~/components/designSystem/Skeleton'

export const VERTICAL_MENU_SKELETON_TEST_ID = 'vertical-menu-skeleton'
export const VERTICAL_MENU_SKELETON_ITEM_TEST_ID = 'vertical-menu-skeleton-item'

export const VerticalMenuSkeleton = ({ numberOfElements }: { numberOfElements: number }) => {
  return (
    <div className="mt-1 flex flex-1 flex-col gap-4" data-test={VERTICAL_MENU_SKELETON_TEST_ID}>
      {Array.from({ length: numberOfElements }).map((_, i) => (
        <div
          key={`skeleton-upper-nav-${i}`}
          className="flex flex-1 flex-row items-center gap-1 pt-1"
          data-test={VERTICAL_MENU_SKELETON_ITEM_TEST_ID}
        >
          <Skeleton variant="circular" size="small" />
          <Skeleton variant="text" className="w-30" />
        </div>
      ))}
    </div>
  )
}
