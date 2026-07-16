import { gql } from '@apollo/client'

import {
  PremiumIntegrationTypeEnum,
  useDownloadPaymentReceiptPdfMutation,
  useDownloadPaymentReceiptXmlMutation,
} from '~/generated/graphql'
import { useDownloadFile } from '~/hooks/useDownloadFile'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  mutation downloadPaymentReceiptPdf($input: DownloadPaymentReceiptInput!) {
    downloadPaymentReceipt(input: $input) {
      id
      fileUrl
    }
  }
  mutation downloadPaymentReceiptXml($input: DownloadXMLPaymentReceiptInput!) {
    downloadXmlPaymentReceipt(input: $input) {
      id
      xmlUrl
    }
  }
`

const useDownloadPaymentReceipts = () => {
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()
  const { hasPermissions } = usePermissions()
  const { handleDownloadFile, handleDownloadFileWithCors } = useDownloadFile()

  const canDownloadPaymentReceipts =
    hasPermissions(['invoicesView']) &&
    hasOrganizationPremiumAddon(PremiumIntegrationTypeEnum.IssueReceipts)

  const [downloadReceipt] = useDownloadPaymentReceiptPdfMutation({
    onCompleted({ downloadPaymentReceipt }) {
      handleDownloadFile(downloadPaymentReceipt?.fileUrl)
    },
  })

  const [downloadReceiptXml] = useDownloadPaymentReceiptXmlMutation({
    onCompleted({ downloadXmlPaymentReceipt }) {
      handleDownloadFileWithCors(downloadXmlPaymentReceipt?.xmlUrl)
    },
  })

  const downloadPaymentReceipts = ({ paymentReceiptId }: { paymentReceiptId?: string }) => {
    if (!paymentReceiptId) {
      return null
    }

    downloadReceipt({
      variables: {
        input: {
          id: paymentReceiptId,
        },
      },
    })
  }

  const downloadPaymentXmlReceipts = ({ paymentReceiptId }: { paymentReceiptId?: string }) => {
    if (!paymentReceiptId) {
      return null
    }

    downloadReceiptXml({
      variables: {
        input: {
          id: paymentReceiptId,
        },
      },
    })
  }

  return {
    canDownloadPaymentReceipts,
    downloadPaymentReceipts,
    downloadPaymentXmlReceipts,
  }
}

export default useDownloadPaymentReceipts
