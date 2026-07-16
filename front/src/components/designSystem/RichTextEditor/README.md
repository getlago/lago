# Rich Text Editor

## Architecture

```
RichTextEditor/
├── extensions/                    # TipTap extensions
│   ├── baseExtensions.ts          # Shared extensions (StarterKit, Table, Link, etc.)
│   ├── Mention.schema.ts          # Mention schema + renderHTML (single source of truth)
│   ├── PlanBlock.schema.ts        # PlanBlock schema + renderHTML + getPlanBlockPreviewData
│   ├── PlanBlock.ts               # PlanBlock + React NodeView (edit mode)
│   ├── LinkCard.ts                # LinkCard (no NodeView needed)
│   ├── SlashCommands.ts           # Slash commands menu
│   ├── LinkPasteHandler.ts        # Auto-detect pasted links
│   └── TemplateSelectorExtension.ts
├── PlanBlock/                     # React components for PlanBlock edit mode
│   ├── PlanBlockView.tsx          # NodeView (edit mode only)
│   └── PlanBlockDrawerContent.tsx # Plan selection drawer
├── MentionNodeView.tsx            # Mention NodeView (edit mode only)
├── RichTextEditor.tsx             # Main editor component
├── RichTextEditorContext.tsx       # React context for edit mode
├── printHtmlContent.ts            # iframe + window.print() engine
└── richTextEditor.css             # Styles (scoped to .ProseMirror)
```

## How preview and PDF rendering works

Both on-screen preview and PDF download mount the **same `<RichTextEditor mode="preview" />`** component. React NodeViews (e.g. `PricingBlockView` rendering `OneOffAddOnsPreviewTable`) run in both paths.

```
<RichTextEditor mode="preview" .../>
    |
    +-- On-screen preview:  mounted directly in the page (visible)
    +-- PDF download:       mounted off-screen by QuotePdfProvider
                            --> onPreviewReady(editor.view.dom.innerHTML)
                            --> printHtmlContent (hidden iframe + window.print())
```

The PDF path is driven by `QuotePdfProvider` (`src/pages/quotes/common/QuotePdfProvider.tsx`). It renders the preview editor in a hidden off-screen container (`fixed -left-[9999px]`). When TipTap signals readiness via `onPreviewReady`, the provider captures `editor.view.dom.innerHTML` — the fully rendered React NodeView DOM — and passes it to `printHtmlContent`.

This means a node's **preview and PDF appearance is determined by its React NodeView** (if it has one). `renderHTML()` is used for the editable/in-document representation and for markdown serialization — it is NOT used to produce preview or PDF output for nodes that have a NodeView.

## Creating a custom node

This guide walks through creating a new custom TipTap node that works in:

- The interactive editor (edit mode)
- On-screen preview (via the React NodeView)
- PDF download (via the same React NodeView, rendered off-screen by `QuotePdfProvider`)

We'll use a fictional `CustomerBlock` as an example.

### Step 1: Create the schema

The schema defines the node's data model, markdown serialization, and in-document HTML representation. It has **zero React imports** — keeping the `.schema.ts` file React-free is still good practice for testability and separation of concerns.

Create `extensions/CustomerBlock.schema.ts`:

```ts
import { mergeAttributes, Node } from '@tiptap/core'

// 1. Define your attributes type
export interface CustomerBlockAttributes {
  customerId: string
}

// 2. Define options for resolution data (used by renderHTML)
export interface CustomerBlockOptions {
  customers: Record<string, { name: string; email: string }>
}

// 3. Create the schema
export const CustomerBlockSchema = Node.create({
  name: 'customerBlock',
  group: 'block',
  atom: true,

  // Declare options with defaults. These are passed via .configure().
  addOptions() {
    return {
      customers: {} as CustomerBlockOptions['customers'],
    }
  },

  // Define the node's attributes and how to parse them from HTML.
  addAttributes() {
    return {
      customerId: {
        default: '',
        parseHTML: (element) => element.dataset.customerId ?? '',
      },
    }
  },

  // Markdown round-trip: serialize to markdown and parse back.
  addStorage() {
    return {
      markdown: {
        serialize(
          state: { write: (text: string) => void; closeBlock: (node: unknown) => void },
          node: { attrs: CustomerBlockAttributes },
        ) {
          // Choose a markdown format for your node
          state.write(`<!-- entity:customer:${node.attrs.customerId} -->`)
          state.closeBlock(node)
        },
        parse: {
          // Convert your markdown format back into an HTML element that parseHTML can pick up
          updateDOM(element: HTMLElement) {
            element.innerHTML = element.innerHTML.replaceAll(
              /<!--\s*entity:customer:(\S*?)\s*-->/g,
              (_match: string, customerId: string) =>
                `<div data-type="customer-block" data-customer-id="${customerId}"></div>`,
            )
          },
        },
      },
    }
  },

  // How to recognize this node when parsing HTML
  parseHTML() {
    return [{ tag: 'div[data-type="customer-block"]' }]
  },

  // How to render this node to in-document HTML (editable mode) and markdown serialization.
  // NOTE: for nodes with a React NodeView, this does NOT control preview or PDF appearance —
  // those use the NodeView's rendered output. Keep renderHTML consistent with the NodeView's
  // structure for HTML round-trip fidelity.
  // When `customers` data is available (via options), render the resolved view.
  renderHTML({ HTMLAttributes }) {
    const customerId = String(HTMLAttributes.customerId ?? '')
    const customer = this.options.customers?.[customerId]

    const wrapperAttrs = mergeAttributes(HTMLAttributes, {
      'data-type': 'customer-block',
      'data-customer-id': customerId,
      class: 'customer-block',
    })

    if (customer) {
      return [
        'div',
        wrapperAttrs,
        ['span', { class: 'customer-block__name' }, customer.name],
        ['span', { class: 'customer-block__email' }, customer.email],
      ]
    }

    // Fallback when no customer data is available
    return [
      'div',
      wrapperAttrs,
      ['span', { class: 'customer-block__placeholder' }, customerId || 'Select a customer'],
    ]
  },
})
```

### Step 2: Create the editor extension (with NodeView)

The editor extension adds the React NodeView for edit mode interactivity. It extends the schema from step 1.

Create `extensions/CustomerBlock.ts`:

```ts
import { ReactNodeViewRenderer } from '@tiptap/react'

import { CustomerBlockSchema } from './CustomerBlock.schema'

import { CustomerBlockView } from '../CustomerBlock/CustomerBlockView'

export type { CustomerBlockAttributes } from './CustomerBlock.schema'

export const CustomerBlock = CustomerBlockSchema.extend({
  addNodeView() {
    return ReactNodeViewRenderer(CustomerBlockView)
  },
})
```

### Step 3: Create the NodeView component

The NodeView controls both **edit mode** interaction AND **preview/PDF appearance**. Because `QuotePdfProvider` renders the full React tree off-screen, the NodeView is what appears in PDFs — not `renderHTML`. If your node needs rich visual output in previews or PDFs, implement it in the NodeView.

Create `CustomerBlock/CustomerBlockView.tsx`:

```tsx
import { NodeViewProps, NodeViewWrapper } from '@tiptap/react'

export const CustomerBlockView = ({ node, updateAttributes, selected }: NodeViewProps) => {
  const customerId = String(node.attrs.customerId ?? '')
  const isEmpty = !customerId

  if (isEmpty) {
    return (
      <NodeViewWrapper>
        <button
          className={`customer-block customer-block--empty ${selected ? 'customer-block--selected' : ''}`}
        >
          <span className="customer-block__placeholder">Select a customer</span>
        </button>
      </NodeViewWrapper>
    )
  }

  return (
    <NodeViewWrapper>
      <button className={`customer-block ${selected ? 'customer-block--selected' : ''}`}>
        <span>Customer: {customerId}</span>
      </button>
    </NodeViewWrapper>
  )
}
```

### Step 4: Add CSS styles

Add styles in `richTextEditor.css` inside the `.ProseMirror` scope. These apply to both the editor and the PDF (stylesheets are copied into the print iframe).

```css
.ProseMirror {
  /* ... existing styles ... */

  .customer-block {
    @apply my-2 rounded-lg border border-grey-300 p-3;
  }

  .customer-block__name {
    @apply text-base font-medium text-grey-700;
  }

  .customer-block__email {
    @apply text-sm text-grey-500;
  }
}
```

### Step 5: Register the extension

**In `RichTextEditor.tsx`** (editor with interactive NodeView):

```ts
import { CustomerBlock } from './extensions/CustomerBlock'

// Inside useEditor extensions array:
extensions: [
  ...getBaseExtensions(),
  // ...other extensions...
  CustomerBlock.configure({ customers: customersFromProps }),
]
```

If your node does **not** need resolution data (like `LinkCard`), add it to `baseExtensions.ts` instead and it works everywhere automatically.

### Step 6: Add tests

At minimum, create two test files:

1. `__tests__/CustomerBlock.test.ts` -- test the schema (renderHTML with/without data, markdown serialization, parseHTML)
2. `__tests__/CustomerBlockView.test.tsx` -- test the NodeView (edit mode interactions)

The schema test should use a real `Editor` instance to test `renderHTML` via `getHTML()`:

```ts
const getHtml = (customerId: string, customers?: Record<string, unknown>) => {
  const editor = new Editor({
    extensions: [StarterKit, CustomerBlockSchema.configure({ customers })],
    content: {
      type: 'doc',
      content: [{ type: 'customerBlock', attrs: { customerId } }],
    },
  })
  const html = editor.getHTML()
  editor.destroy()
  return html
}
```

## Summary: where to change what

| What you want to change                 | Where to edit                                                                |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| How a node looks in **preview and PDF** | The React NodeView (if present); `renderHTML()` for nodes without a NodeView |
| How a node behaves in **edit mode**     | The `NodeView` component (`*View.tsx`)                                       |
| **Markdown** serialization format       | `addStorage()` in the `.schema.ts` file                                      |
| Shared styles (editor + PDF)            | `richTextEditor.css` inside `.ProseMirror`                                   |
| Which extensions are always included    | `baseExtensions.ts`                                                          |

## Key rules

1. **The React NodeView is the source of truth for preview/PDF appearance** when a node has one. `renderHTML` controls the in-document (editable) HTML and markdown serialization, not the preview/PDF output. Never assume `renderHTML` drives what users see in previews.
2. **NodeViews render in both edit mode AND preview/PDF** (via `QuotePdfProvider`'s off-screen render). They may have interactive branches for edit mode, but the base visual output must look correct in read-only/preview mode too.
3. **Split schema from view:** `.schema.ts` has zero React imports (headless-safe). `.ts` extends it with `addNodeView()`.
4. **Resolution data flows via `addOptions` + `.configure()`**. The schema declares options, consumers pass data at configuration time.
5. **Styles go in `richTextEditor.css`** scoped to `.ProseMirror`. They apply to both the editor and PDF automatically.
