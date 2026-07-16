import {
  addToast,
  extractThirdPartyErrorMessage,
  hasDefinedGQLError,
  PspErrorCode,
} from '~/core/apolloClient'
import { LagoApiError, useGeneratePaymentUrlMutation } from '~/generated/graphql'
import { useDownloadFile } from '~/hooks/useDownloadFile'

export const useGeneratePaymentUrl = () => {
  const { openNewTab } = useDownloadFile()

  const [generatePaymentUrl] = useGeneratePaymentUrlMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity, PspErrorCode.ThirdPartyError],
    },
    onCompleted({ generatePaymentUrl: generatedPaymentUrl }) {
      if (generatedPaymentUrl?.paymentUrl) {
        openNewTab(generatedPaymentUrl.paymentUrl)
      }
    },
    onError(resError) {
      if (hasDefinedGQLError('MissingPaymentProviderCustomer', resError)) {
        addToast({
          severity: 'danger',
          translateKey: 'text_1756225393560tonww8d3bgq',
        })
        return
      }

      const pspMessage = extractThirdPartyErrorMessage(resError)

      if (pspMessage) {
        addToast({
          severity: 'danger',
          message: pspMessage,
        })
      }
    },
  })

  return { generatePaymentUrl }
}
