import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import {
  CentralizedDialogProps,
  useCentralizedDialog,
} from '~/components/dialogs/CentralizedDialog'
import { OPEN_OTHER_DIALOG_PARAMS } from '~/components/dialogs/const'
import { useDialogOpeningDialog } from '~/components/dialogs/DialogOpeningDialog'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { TextInput } from '~/components/form'

import Block from '../common/Block'
import Container from '../common/Container'

const LongModalHeaderContent = () => {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-4">
        <Typography>To</Typography>
        <TextInput />
      </div>
      <div className="flex flex-row gap-4">
        <Typography>Cc</Typography>
        <TextInput />
      </div>
      <div className="flex flex-row gap-4">
        <Typography>Bcc</Typography>
        <TextInput />
      </div>
      <div className="flex flex-row gap-4">
        <Typography>Subject</Typography>
        <TextInput />
      </div>
    </div>
  )
}

const LongModalContent = () => <div className="h-[600px] py-8 text-center">Email content</div>

const ModalTest = (): JSX.Element => {
  const modal = useCentralizedDialog()
  const premiumWarningModal = usePremiumWarningDialog()
  const dialogOpeningModal = useDialogOpeningDialog()

  const centralizedDialogProps: CentralizedDialogProps = {
    title: 'Test Modal',
    description: 'This is a description for the long modal.',
    headerContent: <LongModalHeaderContent />,
    children: <LongModalContent />,
    actionText: 'Confirm',
    onAction: () => {
      if (Math.round(Math.random()) > 0) {
        throw new Error('hey')
      }

      return {
        reason: 'success',
        params: 'lol',
      }
    },
  }

  const handleRandomErrorSuccess = (): void => {
    modal
      .open(centralizedDialogProps)
      .then((p) => {
        /* TODO: Remove this line */
        // eslint-disable-next-line no-console
        console.log('success', p)
      })
      .catch((e) => {
        /* TODO: Remove this line */
        // eslint-disable-next-line no-console
        console.log('error', e)
      })
  }
  const handleDialogOpeningDialog = (): void => {
    dialogOpeningModal
      .open({
        title: 'Open another',
        description: 'will open another dialog',
        canOpenDialog: true,
        actionText: 'Action',
        onAction: () => {},
        openDialogText: 'Open other',
        otherDialogProps: centralizedDialogProps,
      })
      .then((p) => {
        /* TODO: Remove this line */
        // eslint-disable-next-line no-console
        console.log('success out', p)
        if (p.reason === OPEN_OTHER_DIALOG_PARAMS.reason) {
          const otherPromise = p.otherDialog

          otherPromise.then((value) => {
            /* TODO: Remove this line */
            // eslint-disable-next-line no-console
            console.log('value', value)
          })
        }
      })
      .catch((e) => {
        /* TODO: Remove this line */
        // eslint-disable-next-line no-console
        console.log('error out', e)
      })
  }

  return (
    <Container>
      <Typography className="mb-4" variant="headline">
        Dialogs
      </Typography>
      <Typography className="mb-4" variant="subhead1">
        Simple &#60;Dialogs/&#62;, open console to see results
      </Typography>
      <Block className="flex-col">
        <Button onClick={() => premiumWarningModal.open()}>Open Premium Warning Modal</Button>
        <Button onClick={handleRandomErrorSuccess}>Open Random Example</Button>
        <Button onClick={handleDialogOpeningDialog}>Open Dialog opening dialog</Button>
      </Block>
    </Container>
  )
}

export default ModalTest
