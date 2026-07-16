import { FormikProps } from 'formik'

import { CreditNoteForm } from '~/components/creditNote/types'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import MetadataForm from './MetadataForm'

type MetadataFormCardProps = {
  formikProps: FormikProps<Partial<CreditNoteForm>>
}

const MetadataFormCard = ({ formikProps }: MetadataFormCardProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <Typography variant="subhead1">{translate('text_63fcc3218d35b9377840f59b')}</Typography>
        <Typography variant="caption">{translate('text_1764595550459v75grmg3do9')}</Typography>
      </div>
      <MetadataForm formikProps={formikProps} />
    </div>
  )
}

export default MetadataFormCard
