import { Fragment, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { type GetCreditNoteForDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  MetadataEditDrawer,
  MetadataEditDrawerRef,
} from '~/pages/creditNoteDetails/metadataEditDrawer/MetadataEditDrawer'
import { SectionHeader } from '~/styles/customer'

type CreditNotesDetailsMetadataProps = {
  creditNote: GetCreditNoteForDetailsQuery['creditNote']
}

const GRID =
  'grid grid-cols-1 md:grid-cols-[fit-content(100%)_1fr] gap-x-8 md:gap-y-2 [&>*:nth-child(odd):not(:first-child)]:mt-2 md:[&>*:nth-child(odd):not(:first-child)]:mt-0'

const CreditNoteDetailsMetadata = ({ creditNote }: CreditNotesDetailsMetadataProps) => {
  const { translate } = useInternationalization()
  const metadataEditDrawerRef = useRef<MetadataEditDrawerRef>(null)

  const handleOpenMetadataEditDrawer = () => {
    metadataEditDrawerRef.current?.openDrawer({ creditNote })
  }

  return (
    <div>
      <SectionHeader variant="subhead1">
        {translate('text_63fcc3218d35b9377840f59b')}
        <Button variant="inline" onClick={handleOpenMetadataEditDrawer}>
          {translate('text_63e51ef4985f0ebd75c212fc')}
        </Button>
      </SectionHeader>

      <div className="mt-6">
        {!creditNote?.metadata?.length && (
          <Typography variant="caption" color="grey600">
            {translate('text_1764666863501j6vdc3bjjb9')}
          </Typography>
        )}

        <div className={GRID}>
          {creditNote?.metadata?.map((metadata) => (
            <Fragment key={metadata.key}>
              <Typography variant="body" color="grey600">
                {metadata.key}
              </Typography>
              <Typography variant="body" color="grey700">
                {metadata.value}
              </Typography>
            </Fragment>
          ))}
        </div>
      </div>

      <MetadataEditDrawer ref={metadataEditDrawerRef} />
    </div>
  )
}

export default CreditNoteDetailsMetadata
