import { Skeleton } from '~/components/designSystem/Skeleton'

const CustomerPortalLoading = () => (
  <div className="flex items-center">
    <Skeleton className="w-30" variant="text" />
    <Skeleton className="mr-3" variant="connectorAvatar" size="big" />
  </div>
)

export default CustomerPortalLoading
