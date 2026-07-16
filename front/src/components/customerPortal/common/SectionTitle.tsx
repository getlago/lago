import TextButton from '~/components/customerPortal/common/TextButton'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

type SectionTitleProps = {
  className?: string
  title: string
  action?: { title: string; onClick: () => void }
  loading?: boolean
}

const SectionTitle = ({ className, title, action, loading }: SectionTitleProps) => (
  <div className={tw('mb-6 flex items-center pb-4 shadow-b', className)}>
    {loading ? (
      <div className="flex h-7 w-full items-center">
        <Skeleton variant="text" className="w-40" />
      </div>
    ) : (
      <>
        <Typography variant="subhead1" color="grey700">
          {title}
        </Typography>

        {action && <TextButton onClick={action.onClick} content={action.title} />}
      </>
    )}
  </div>
)

export default SectionTitle
