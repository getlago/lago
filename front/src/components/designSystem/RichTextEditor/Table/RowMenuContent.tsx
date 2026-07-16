import type { Editor } from '@tiptap/core'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import { focusCellAndRun } from './tableUtils'

import ColorPicker from '../BlockControls/ColorPicker'

type RowMenuContentProps = {
  cellPos: number
  rowIndex: number
  totalRows: number
  rowColors: { backgroundColor: string | null; textColor: string | null } | null
  editor: Editor
  closePopper: () => void
}

const RowMenuContent = ({
  cellPos,
  rowIndex,
  totalRows,
  rowColors,
  editor,
  closePopper,
}: RowMenuContentProps) => {
  const { translate } = useInternationalization()

  return (
    <MenuPopper>
      {/* Colors */}
      <Popper
        PopperProps={{ placement: 'right-start' }}
        opener={
          <Button variant="quaternary" align="left" className="w-full" startIcon="text-color">
            {translate('text_17751458820889ebguo3021w')}
          </Button>
        }
      >
        {() => (
          <MenuPopper>
            <ColorPicker
              activeBackgroundColor={rowColors?.backgroundColor ?? null}
              activeTextColor={rowColors?.textColor ?? null}
              onSelectBackground={(color) => {
                focusCellAndRun(editor, cellPos, (chain) => chain.setRowBackgroundColor(color))
              }}
              onSelectText={(color) => {
                focusCellAndRun(editor, cellPos, (chain) => chain.setRowTextColor(color))
              }}
            />
          </MenuPopper>
        )}
      </Popper>

      {/* Move up */}
      <Button
        variant="quaternary"
        startIcon="arrow-top"
        align="left"
        disabled={rowIndex === 0}
        onClick={() => {
          focusCellAndRun(editor, cellPos, (chain) => chain.moveRowUp())
          closePopper()
        }}
      >
        {translate('text_17756354158189xlxmul84lu')}
      </Button>

      {/* Move down */}
      <Button
        variant="quaternary"
        startIcon="arrow-bottom"
        align="left"
        disabled={rowIndex === totalRows - 1}
        onClick={() => {
          focusCellAndRun(editor, cellPos, (chain) => chain.moveRowDown())
          closePopper()
        }}
      >
        {translate('text_1775635415819dqd4uqcq6jl')}
      </Button>

      {/* Delete row */}
      {totalRows > 1 && (
        <Button
          variant="quaternary"
          startIcon="trash"
          align="left"
          onClick={() => {
            focusCellAndRun(editor, cellPos, (chain) => chain.deleteRow())
            closePopper()
          }}
        >
          {translate('text_17756367818356w28cspf5y7')}
        </Button>
      )}
    </MenuPopper>
  )
}

export default RowMenuContent
