import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'

const PageTitle = ({ title, goHome }: { title: string; goHome: () => void }) => {
  return (
    <div className="mb-8 flex items-center gap-3">
      <Button
        className="text-grey-600"
        icon="arrow-left"
        variant="quaternary"
        onClick={() => goHome()}
      />

      <Typography variant="subhead1" color="grey700">
        {title}
      </Typography>
    </div>
  )
}

export default PageTitle
