import type { Node as PmNode } from '@tiptap/pm/model'
import { type EditorState, NodeSelection } from '@tiptap/pm/state'

export const resolveTopLevelBlock = (state: EditorState): { pos: number; node: PmNode } | null => {
  const { selection } = state

  if (selection instanceof NodeSelection) {
    return { pos: selection.from, node: selection.node }
  }

  const $pos = selection.$from

  if ($pos.depth >= 1) {
    return { pos: $pos.before(1), node: $pos.node(1) }
  }

  return null
}
