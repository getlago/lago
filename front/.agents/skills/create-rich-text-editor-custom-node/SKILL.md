---
name: create-rich-text-editor-custom-node
description: Create a new custom TipTap node for the Rich Text Editor that works in edit mode, on-screen preview, and PDF download. Generates the schema, editor extension, NodeView component, CSS styles, tests, and registers the extension.
user-invocable: true
argument-hint: '<node-name>'
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion
---

# Create Rich Text Editor Custom Node

This guide helps create a new custom TipTap node for the Rich Text Editor following the project's architecture conventions. The node will work across all three rendering contexts: edit mode (interactive), on-screen preview, and PDF download.

## Architecture Overview

```
renderHTML() in .schema.ts  <-- single source of truth for preview + PDF
    |
    +-- On-screen preview:  editor.getHTML() --> dangerouslySetInnerHTML
    +-- PDF download:       editor.getHTML() --> printHtmlContent (hidden iframe)

NodeView (edit mode only)   <-- interactive UI, no preview logic
```

All files live under `src/components/designSystem/RichTextEditor/`.

## Key Rules

1. **`renderHTML` is the single source of truth** for preview/PDF appearance. Never duplicate rendering logic in NodeViews.
2. **NodeViews are for edit mode only.** No `if (isPreview)` branches.
3. **Split schema from view:** `.schema.ts` has zero React imports (headless-safe). `.ts` extends it with `addNodeView()`.
4. **Resolution data flows via `addOptions()` + `.configure()`**. The schema declares options, consumers pass data at configuration time.
5. **Styles go in `richTextEditor.css`** scoped to `.ProseMirror`. They apply to both the editor and PDF automatically.

## Reference Files

Read these before starting:

- **Base extensions**: `extensions/baseExtensions.ts`
- **Schema with resolution data**: `extensions/PlanBlock.schema.ts`
- **Schema extending TipTap built-in**: `extensions/Mention.schema.ts`
- **Editor extension wrapping schema**: `extensions/PlanBlock.ts`
- **Simple node (no NodeView)**: `extensions/LinkCard.ts`
- **NodeView (edit mode only)**: `PlanBlock/PlanBlockView.tsx`
- **Editor component**: `RichTextEditor.tsx`
- **PDF download**: `downloadMarkdownPdf.ts`
- **Schema test**: `__tests__/PlanBlock.test.ts`

## Extension Pattern Decision

| Pattern | When to use | Files to create |
|---|---|---|
| **Schema only** (like LinkCard) | No interactive edit UI, no resolution data | `extensions/YourNode.ts` only |
| **Schema + NodeView** (like PlanBlock) | Needs interactive edit UI and/or resolution data | `extensions/YourNode.schema.ts` + `extensions/YourNode.ts` + `YourNode/YourNodeView.tsx` |

## Step 1: Create the Schema

Create `extensions/{NodeName}.schema.ts` with zero React imports:

```ts
import { mergeAttributes, Node } from '@tiptap/core'

export interface YourNodeAttributes {
  yourId: string
}

export const YourNodeSchema = Node.create({
  name: 'yourNode',
  group: 'block',
  atom: true,

  // Only needed if renderHTML uses external data for resolution
  addOptions() {
    return {
      items: {} as Record<string, { name: string }>,
    }
  },

  addAttributes() {
    return {
      yourId: {
        default: '',
        parseHTML: (element) => element.dataset.yourId ?? '',
      },
    }
  },

  // Markdown serialization
  addStorage() {
    return {
      markdown: {
        serialize(
          state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
          node: { attrs: YourNodeAttributes },
        ) {
          state.write(`<!-- entity:yourtype:${node.attrs.yourId} -->`)
          state.closeBlock(node)
        },
        parse: {
          updateDOM(element: HTMLElement) {
            element.innerHTML = element.innerHTML.replaceAll(
              /<!--\s*entity:yourtype:(\S*?)\s*-->/g,
              (_match: string, yourId: string) =>
                `<div data-type="your-node" data-your-id="${yourId}"></div>`,
            )
          },
        },
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="your-node"]' }]
  },

  // SINGLE SOURCE OF TRUTH for preview and PDF
  renderHTML({ HTMLAttributes }) {
    const yourId = String(HTMLAttributes.yourId ?? '')
    const item = this.options.items?.[yourId]

    const wrapperAttrs = mergeAttributes(HTMLAttributes, {
      'data-type': 'your-node',
      'data-your-id': yourId,
      class: 'your-node',
    })

    if (item) {
      return ['div', wrapperAttrs, ['span', { class: 'your-node__name' }, item.name]]
    }

    return ['div', wrapperAttrs, ['span', { class: 'your-node__placeholder' }, yourId || 'Select...']]
  },
})
```

## Step 2: Create the Editor Extension

Create `extensions/{NodeName}.ts`:

```ts
import { ReactNodeViewRenderer } from '@tiptap/react'
import { YourNodeView } from '../YourNode/YourNodeView'
import { YourNodeSchema } from './YourNode.schema'

export type { YourNodeAttributes } from './YourNode.schema'

export const YourNode = YourNodeSchema.extend({
  addNodeView() {
    return ReactNodeViewRenderer(YourNodeView)
  },
})
```

## Step 3: Create the NodeView (Edit Mode Only)

Create `{NodeName}/{NodeName}View.tsx`:

```tsx
import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'

export const YourNodeView = ({ node, updateAttributes, selected }: NodeViewProps) => {
  const yourId = String(node.attrs.yourId ?? '')
  const isEmpty = !yourId

  // Edit mode UI only. No preview branches.
  if (isEmpty) {
    return (
      <NodeViewWrapper>
        <button className={`your-node your-node--empty ${selected ? 'your-node--selected' : ''}`}>
          <span className="your-node__placeholder">Select...</span>
        </button>
      </NodeViewWrapper>
    )
  }

  return (
    <NodeViewWrapper>
      <button className={`your-node ${selected ? 'your-node--selected' : ''}`}>
        <span>Item: {yourId}</span>
      </button>
    </NodeViewWrapper>
  )
}
```

## Step 4: Add CSS Styles

In `richTextEditor.css` inside `.ProseMirror`:

```css
.your-node {
  @apply my-2 rounded-lg border border-grey-300 p-3;
}

.your-node__name {
  @apply text-base font-medium text-grey-700;
}
```

## Step 5: Register the Extension

**If the node needs resolution data:**

In `RichTextEditor.tsx` extensions array:
```ts
YourNode.configure({ items: itemsFromProps }),
```

In `downloadMarkdownPdf.ts` extensions array:
```ts
YourNodeSchema.configure({ items }),
```

Also add the new data to `DownloadMarkdownPdfOptions` and to `RichTextEditorProps`.

**If the node does NOT need resolution data:**

Add it to `baseExtensions.ts`:
```ts
export const getBaseExtensions = (): Extensions => [
  // ...existing...
  YourNode,
]
```

## Step 6: Add Tests

### Schema test (`__tests__/{NodeName}.test.ts`)

Test `renderHTML` via a real Editor instance:

```ts
const getHtml = (attrs: Record<string, unknown>, options?: Record<string, unknown>) => {
  const editor = new Editor({
    extensions: [StarterKit, YourNodeSchema.configure(options)],
    content: { type: 'doc', content: [{ type: 'yourNode', attrs }] },
  })
  const html = editor.getHTML()
  editor.destroy()
  return html
}
```

Test: renderHTML with/without resolution data, markdown serialize/parse, parseHTML.

### NodeView test (`__tests__/{NodeName}View.test.tsx`)

Test edit mode interactions only. No preview tests.

## Verification Checklist

- [ ] Schema file has zero React imports
- [ ] `renderHTML` handles both resolved and fallback cases
- [ ] NodeView has no `if (isPreview)` branches
- [ ] Markdown round-trips correctly (serialize -> parse -> same node)
- [ ] CSS is scoped inside `.ProseMirror`
- [ ] Extension registered in `RichTextEditor.tsx` and `downloadMarkdownPdf.ts` (or `baseExtensions.ts`)
- [ ] `npx tsc --noEmit` passes
- [ ] `npx jest --no-coverage src/components/designSystem/RichTextEditor/__tests__/` passes
