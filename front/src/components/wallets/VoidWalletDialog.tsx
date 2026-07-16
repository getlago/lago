import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { number, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { AmountInputField, TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useNavigate, WALLET_DETAILS_ROUTE } from '~/core/router'
import { CurrencyEnum, useCreateCustomerWalletTransactionMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'

gql`
  fragment WalletForVoidTransaction on Wallet {
    id
    currency
    rateAmount
    creditsBalance
  }
`

type WalletProps = {
  walletId?: string
  creditsBalance?: number
  currency?: CurrencyEnum
  rateAmount?: number
}

export type VoidWalletDialogRef = {
  openDialog: (props?: WalletProps) => unknown
  closeDialog: () => unknown
}

export const VoidWalletDialog = forwardRef<VoidWalletDialogRef>((_, ref) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const [localData, setLocalData] = useState<WalletProps | null>(null)
  const dialogRef = useRef<DialogRef>(null)
  const { customerId } = useParams()

  const [createVoidTransaction] = useCreateCustomerWalletTransactionMutation({
    onCompleted(res) {
      if (res?.createCustomerWalletTransaction) {
        addToast({
          severity: 'success',
          translateKey: 'text_662fde6f41f3c001313057b8',
        })
      }
    },
  })

  const formikProps = useFormik({
    initialValues: {
      name: undefined,
      voidCredits: undefined,
    },
    validationSchema: object().shape({
      name: string(),
      voidCredits: number()
        .required('')
        .max(
          localData?.creditsBalance as number,
          translate('text_662fc2730f9a31fe564e9dbf', { balance: localData?.creditsBalance }),
        ),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    isInitialValid: false,
    onSubmit: async ({ voidCredits, name }) => {
      await createVoidTransaction({
        variables: {
          input: {
            walletId: localData?.walletId as string,
            voidedCredits: String(voidCredits),
            name: name || undefined,
          },
        },
        refetchQueries: ['getCustomerWalletList', 'getWalletTransactions'],
        notifyOnNetworkStatusChange: true,
      })

      navigate(
        generatePath(WALLET_DETAILS_ROUTE, {
          walletId: localData?.walletId as string,
          customerId: customerId as string,
          tab: WalletDetailsTabsOptionsEnum.overview,
        }),
      )
    },
  })

  useImperativeHandle(ref, () => ({
    openDialog: (props) => {
      if (!props) {
        return
      }

      setLocalData(props)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => dialogRef.current?.closeDialog(),
  }))

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_63720bd734e1344aea75b7e9')}
      description={translate('text_662fc2730f9a31fe564e9dad')}
      onClose={() => formikProps.resetForm()}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_62e79671d23ae6ff149de968')}
          </Button>
          <Button
            disabled={!formikProps.isValid}
            onClick={async () => {
              await formikProps.submitForm()
              closeDialog()
            }}
            danger={formikProps.isValid && formikProps.dirty}
          >
            {translate('text_63720bd734e1344aea75b7e9')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-6">
        <TextInputField
          // eslint-disable-next-line jsx-a11y/no-autofocus
          autoFocus
          name="name"
          formikProps={formikProps}
          label={translate('text_17580145853389xkffv9cs1d')}
          placeholder={translate('text_17580145853390n3v83gao69')}
        />

        <AmountInputField
          name="voidCredits"
          currency={localData?.currency as CurrencyEnum}
          beforeChangeFormatter={['positiveNumber']}
          label={translate('text_662fc2730f9a31fe564e9db1')}
          formikProps={formikProps}
          error={Boolean(formikProps.errors.voidCredits)}
          helperText={
            formikProps.errors.voidCredits
              ? formikProps.errors.voidCredits
              : translate('text_662fc2730f9a31fe564e9dbd', {
                  credits: intlFormatNumber(
                    !isNaN(Number(formikProps.values.voidCredits))
                      ? Number(formikProps.values.voidCredits) * Number(localData?.rateAmount)
                      : 0,
                    {
                      currencyDisplay: 'symbol',
                      currency: localData?.currency,
                    },
                  ),
                })
          }
          InputProps={{
            endAdornment: (
              <InputAdornment position="end">
                {translate('text_62e79671d23ae6ff149de94c')}
              </InputAdornment>
            ),
          }}
        />
      </div>
    </Dialog>
  )
})

VoidWalletDialog.displayName = 'VoidWalletDialog'
