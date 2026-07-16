import SectionTitle from '~/components/customerPortal/common/SectionTitle'
import { Skeleton } from '~/components/designSystem/Skeleton'

const group = (
  <div className="mb-12">
    <SectionTitle title="" loading={true} />

    <div className="grid grid-cols-2">
      <div className="flex flex-col gap-3">
        <Skeleton variant="text" className="w-18" />
        <Skeleton variant="text" className="w-40" />
      </div>

      <div className="flex flex-col gap-3">
        <Skeleton variant="text" className="w-18" />
        <Skeleton variant="text" className="w-40" />
      </div>
    </div>
  </div>
)

export const LoaderUsageSection = () => (
  <div className="grid grid-cols-2">
    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-40" />
      <Skeleton variant="text" className="w-60" />
      <Skeleton variant="text" className="w-18" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-40" />
      <Skeleton variant="text" className="w-60" />
      <Skeleton variant="text" className="w-18" />
    </div>
  </div>
)

export const LoaderUsageSubscriptionItem = () => (
  <div className="flex flex-col gap-3">
    <Skeleton variant="text" className="w-18" />
    <Skeleton variant="text" className="w-40" />
    <Skeleton variant="text" className="w-60" />
    <Skeleton variant="text" className="w-18" />
  </div>
)

export const LoaderWalletPage = () => (
  <div className="mt-8 flex flex-col gap-4">
    {group}
    {group}
    {group}
  </div>
)

export const LoaderWalletSection = () => (
  <div className="grid grid-cols-2">
    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-40" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-40" />
    </div>
  </div>
)

export const LoaderCustomerInformationSection = () => (
  <div className="grid grid-cols-2 gap-6">
    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>

    <div className="flex flex-col gap-3">
      <Skeleton variant="text" className="w-18" />
      <Skeleton variant="text" className="w-60" />
    </div>
  </div>
)

export const LoaderCustomerInformationPage = () => (
  <div className="mt-8 flex flex-col gap-4">
    {group}
    {group}
    {group}
  </div>
)

export const LoaderInvoicesListSection = () => (
  <div className="mt-8 flex flex-col gap-4">
    {group}
    {group}
    {group}
  </div>
)

export const LoaderInvoicesListTotal = () => (
  <div className="flex flex-col gap-3">
    <Skeleton variant="text" className="w-18" />
    <Skeleton variant="text" className="w-60" />
  </div>
)

export const LoaderSidebarOrganization = () => (
  <div className="flex flex-col gap-8">
    <Skeleton className="w-8 !rounded-[8px] bg-grey-200" variant="text" />
    <Skeleton className="w-57 bg-grey-200" variant="text" />
  </div>
)

const SectionLoading = () => {
  return (
    <div className="flex flex-col gap-2">
      <Skeleton variant="text" className="w-30" />
      <Skeleton variant="text" className="w-40" />
      <Skeleton variant="text" className="w-50" />
    </div>
  )
}

export default SectionLoading
