import type { DOMOutputSpec } from '@tiptap/pm/model'

/**
 * Wraps a block node's renderHTML output in the standard spacer/block-wrapper structure:
 *
 * ```html
 * <div class="spacer" data-type="paragraph">
 *   <div class="block-wrapper">
 *     <p>...</p>
 *   </div>
 * </div>
 * ```
 *
 * This wrapper appears in both the editor DOM and serialized HTML (getHTML, preview, PDF).
 * parseHTML does not need changes — ProseMirror descends through the wrapper divs
 * to find the inner element (e.g., <p>, <h1>).
 */
export const wrapInBlockWrapper = (typeName: string, inner: DOMOutputSpec): DOMOutputSpec => [
  'div',
  { class: 'spacer', 'data-type': typeName },
  ['div', { class: 'block-wrapper' }, inner],
]
