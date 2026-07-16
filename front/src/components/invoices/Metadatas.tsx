import { gql } from '@apollo/client'
import { memo, useRef } from 'react'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import {
  InvoiceMetadatasForMetadataDrawerFragmentDoc,
  useGetInvoiceMetadatasQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { SectionHeader } from '~/styles/customer'

import { AddMetadataDrawer, AddMetadataDrawerRef } from './AddMetadataDrawer'

gql`
  fragment CustomerMetadatasForInvoiceOverview on Customer {
    id
    metadata {
      id
      displayInInvoice
      key
      value
    }
  }

  fragment InvoiceMetadatasForInvoiceOverview on Invoice {
    id
    metadata {
      id
      key
      value
    }
  }

  query getInvoiceMetadatas($id: ID!) {
    invoice(id: $id) {
      id
      ...InvoiceMetadatasForInvoiceOverview
      ...InvoiceMetadatasForMetadataDrawer
      customer {
        ...CustomerMetadatasForInvoiceOverview
      }
    }
  }

  ${InvoiceMetadatasForMetadataDrawerFragmentDoc}
`

const InfoLine = ({
  children,
  ...props
}: { children: React.ReactNode } & React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className="mb-3 flex items-start first-child:mr-3 first-child:min-w-58 first-child:leading-7 last-child:w-full last-child:line-break-anywhere"
    {...props}
  >
    {children}
  </div>
)

export const Metadatas = memo(() => {
  const { translate } = useInternationalization()
  const { invoiceId } = useParams()
  const addMetadataDrawerDialogRef = useRef<AddMetadataDrawerRef>(null)

  const { data, loading } = useGetInvoiceMetadatasQuery({
    variables: {
      id: invoiceId || '',
    },
  })

  const invoice = data?.invoice
  const customer = invoice?.customer

  const customerMetadatas = (customer?.metadata || []).filter((m) => m.displayInInvoice)

  if (loading) {
    return null
  }

  return (
    <>
      <section className="mt-8 flex flex-col gap-6">
        <SectionHeader variant="subhead1">
          {translate('text_6405cac5c833dcf18cad019c')}
          <Button
            variant="quaternary"
            align="left"
            onClick={() => {
              addMetadataDrawerDialogRef?.current?.openDrawer()
            }}
          >
            {translate(
              !!invoice?.metadata?.length
                ? 'text_6405cac5c833dcf18cad0198'
                : 'text_6405cac5c833dcf18cad0196',
            )}
          </Button>
        </SectionHeader>
        <div>
          {invoice?.metadata?.length ? (
            invoice?.metadata.map((metadata) => (
              <InfoLine key={`customer-metadata-${metadata.id}`}>
                <Typography variant="caption" color="grey600" noWrap>
                  {metadata.key}
                </Typography>
                <Typography variant="body" color="grey700">
                  {metadata.value}
                </Typography>
              </InfoLine>
            ))
          ) : (
            <Typography variant="body" color="grey500">
              {translate('text_6405cac5c833dcf18cad01a2')}
            </Typography>
          )}
        </div>
        {!!customerMetadatas.length && (
          <>
            <SectionHeader variant="subhead1">
              {translate('text_63fdc195ee23e51024c607b8')}
            </SectionHeader>
            <div>
              {customerMetadatas.map((metadata) => (
                <InfoLine key={`customer-metadata-${metadata.id}`}>
                  <Typography variant="caption" color="grey600" noWrap>
                    {metadata.key}
                  </Typography>
                  <Typography variant="body" color="grey700">
                    {metadata.value}
                  </Typography>
                </InfoLine>
              ))}
            </div>
          </>
        )}
      </section>

      {invoice && <AddMetadataDrawer ref={addMetadataDrawerDialogRef} invoiceId={invoice?.id} />}
    </>
  )
})

Metadatas.displayName = 'Metadatas'
