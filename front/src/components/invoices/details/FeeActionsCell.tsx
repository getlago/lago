import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { useViewFeeDetailsDrawer } from '~/components/invoices/details/ViewFeeDetailsDrawer'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { FeeForViewFeeDetailsDrawerFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper, PopperOpener } from '~/styles'

import {
  FEE_ACTIONS_BUTTON_TEST_ID,
  FEE_ACTIONS_CELL_TEST_ID,
  FEE_COPY_ID_BUTTON_TEST_ID,
  FEE_VIEW_DETAILS_BUTTON_TEST_ID,
} from './invoiceDetailsTestIds'

type Fee = FeeForViewFeeDetailsDrawerFragment | null | undefined

export const ViewFeeDetailsButton = ({
  fee,
  closePopper,
}: {
  fee: Fee
  closePopper: () => void
}) => {
  const { translate } = useInternationalization()
  const viewFeeDetails = useViewFeeDetailsDrawer()

  return (
    <Button
      startIcon="eye"
      variant="quaternary"
      align="left"
      data-test={FEE_VIEW_DETAILS_BUTTON_TEST_ID}
      onClick={() => {
        if (fee) {
          viewFeeDetails.open(fee)
        }
        closePopper()
      }}
    >
      {translate('text_1778485363573s0yy2srnakn')}
    </Button>
  )
}

export const CopyFeeIdButton = ({ fee, closePopper }: { fee: Fee; closePopper: () => void }) => {
  const { translate } = useInternationalization()

  return (
    <Button
      startIcon="duplicate"
      variant="quaternary"
      align="left"
      data-test={FEE_COPY_ID_BUTTON_TEST_ID}
      onClick={() => {
        if (fee?.id) {
          copyToClipboard(fee.id)
          addToast({
            severity: 'info',
            translateKey: 'text_1775559630554ourrtpgddty',
          })
        }
        closePopper()
      }}
    >
      {translate('text_1778593706862951t256keim')}
    </Button>
  )
}

type FeeActionsCellProps = {
  fee: Fee
}

export const FeeActionsCell = ({ fee }: FeeActionsCellProps) => {
  const { translate } = useInternationalization()

  return (
    <td data-test={FEE_ACTIONS_CELL_TEST_ID} onClick={(e) => e.stopPropagation()}>
      <Popper
        PopperProps={{ placement: 'bottom-end' }}
        opener={({ isOpen }) => (
          <PopperOpener className="static">
            <Tooltip
              placement="top-end"
              disableHoverListener={isOpen}
              title={translate('text_1778485363573s0yy2srnakn')}
            >
              <Button
                size="small"
                icon="dots-horizontal"
                variant="quaternary"
                data-test={FEE_ACTIONS_BUTTON_TEST_ID}
              />
            </Tooltip>
          </PopperOpener>
        )}
      >
        {({ closePopper }) => (
          <MenuPopper>
            <CopyFeeIdButton fee={fee} closePopper={closePopper} />
            <ViewFeeDetailsButton fee={fee} closePopper={closePopper} />
          </MenuPopper>
        )}
      </Popper>
    </td>
  )
}
