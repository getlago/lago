import type { Editor } from '@tiptap/core'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import { focusCellAndRun } from './tableUtils'

import ColorPicker from '../BlockControls/ColorPicker'

type ColMenuContentProps = {
  cellPos: number
  colIndex: number
  totalCols: number
  editor: Editor
  closePopper: () => void
}

const ColMenuContent = ({
  cellPos,
  colIndex,
  totalCols,
  editor,
  closePopper,
}: ColMenuContentProps) => {
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
              activeBackgroundColor={null}
              activeTextColor={null}
              onSelectBackground={(color) => {
                focusCellAndRun(editor, cellPos, (chain) => chain.setColumnBackgroundColor(color))
              }}
              onSelectText={(color) => {
                focusCellAndRun(editor, cellPos, (chain) => chain.setColumnTextColor(color))
              }}
            />
          </MenuPopper>
        )}
      </Popper>

      {/* Move left */}
      <Button
        variant="quaternary"
        startIcon="arrow-left"
        align="left"
        disabled={colIndex === 0}
        onClick={() => {
          focusCellAndRun(editor, cellPos, (chain) => chain.moveColumnLeft())
          closePopper()
        }}
      >
        {translate('text_1775636781835mcmnvqltjb1')}
      </Button>

      {/* Move right */}
      <Button
        variant="quaternary"
        startIcon="arrow-right"
        align="left"
        disabled={colIndex === totalCols - 1}
        onClick={() => {
          focusCellAndRun(editor, cellPos, (chain) => chain.moveColumnRight())
          closePopper()
        }}
      >
        {translate('text_1775636781835jw4g7ynklb3')}
      </Button>

      {/* Delete column */}
      {totalCols > 1 && (
        <Button
          variant="quaternary"
          startIcon="trash"
          align="left"
          onClick={() => {
            focusCellAndRun(editor, cellPos, (chain) => chain.deleteColumn())
            closePopper()
          }}
        >
          {translate('text_1775636781835fuo9er4u938')}
        </Button>
      )}
    </MenuPopper>
  )
}

export default ColMenuContent
