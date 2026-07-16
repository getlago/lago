export const printHtmlContent = (html: string, options?: { title?: string }): void => {
  const iframe = document.createElement('iframe')

  // Off-screen, sized to A4 so the content lays out at a sane print width.
  // (Pagination itself is driven by the html/body overflow reset below, not by
  // these dimensions.)
  iframe.style.position = 'fixed'
  iframe.style.left = '-9999px'
  iframe.style.top = '0'
  iframe.style.width = '794px' // ~A4 width @96dpi (210mm)
  iframe.style.height = '1123px' // ~A4 height @96dpi (297mm)
  iframe.style.border = '0'
  document.body.appendChild(iframe)

  const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document

  if (!iframeDoc) {
    iframe.remove()
    return
  }

  // Chrome derives the print filename from the TOP document's title (handled by
  // the document.title swap before print() below). Setting the iframe's own
  // title is a defensive fallback for browsers that read it instead.
  if (options?.title) {
    iframeDoc.title = options.title
  }

  // Copy all stylesheets from the parent document into the iframe
  const styleSheets = Array.from(document.styleSheets)

  styleSheets.forEach((sheet) => {
    try {
      if (sheet.href) {
        const link = iframeDoc.createElement('link')

        link.rel = 'stylesheet'
        link.href = sheet.href
        iframeDoc.head.appendChild(link)
      } else if (sheet.cssRules) {
        const style = iframeDoc.createElement('style')
        const rules = Array.from(sheet.cssRules)
          .map((rule) => rule.cssText)
          .join('\n')

        style.textContent = rules
        iframeDoc.head.appendChild(style)
      }
    } catch {
      // Skip cross-origin stylesheets that can't be read
    }
  })

  // Force backgrounds to print (browsers strip them by default)
  const printStyle = iframeDoc.createElement('style')

  printStyle.textContent = `
    @page { margin: 0; }
    @media print {
      * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; color-adjust: exact !important; }
    }
    /* The app's global stylesheets (copied in above) put overflow:hidden and a
       fixed height on html/body for the SPA shell. Inside this iframe that turns
       the document into a clip container and the print engine emits only the
       first page. Reset it so long content flows and paginates. */
    html, body { height: auto !important; min-height: 0 !important; overflow: visible !important; }
    body { margin: 0; padding: 0; }
    .print-padding { padding: 20mm; }
  `
  iframeDoc.head.appendChild(printStyle)

  // Wrap the content in a padded div — @page margin: 0 removes default page margins,
  // and the inner padding restores the visual margin (browser print headers/footers may still appear)
  iframeDoc.body.innerHTML = `<div class="print-padding">${html}</div>`

  // Wait for all linked stylesheets to load before printing
  const stylesheetLinks = Array.from(
    iframeDoc.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]'),
  )

  const waitForStylesheets = Promise.all(
    stylesheetLinks.map(
      (link) =>
        new Promise<void>((resolve) => {
          if ((link as unknown as { sheet: CSSStyleSheet | null }).sheet) {
            resolve()
            return
          }

          const onDone = (): void => {
            link.removeEventListener('load', onDone)
            link.removeEventListener('error', onDone)
            resolve()
          }

          link.addEventListener('load', onDone)
          link.addEventListener('error', onDone)
        }),
    ),
  )

  // Wait for images to load before printing. The print HTML can contain remote
  // <img> (e.g. uploaded quote images served via signed URLs); printing before
  // they finish downloading yields blank images in the PDF. Resolve on load OR
  // error (a broken src shouldn't block), and treat already-complete images as
  // ready. Stylesheets never carried this risk — images are the first remote
  // resource in the print HTML.
  const images = Array.from(iframeDoc.querySelectorAll<HTMLImageElement>('img'))

  const waitForImages = Promise.all(
    images.map(
      (img) =>
        new Promise<void>((resolve) => {
          if (img.complete) {
            resolve()
            return
          }

          const onDone = (): void => {
            img.removeEventListener('load', onDone)
            img.removeEventListener('error', onDone)
            resolve()
          }

          img.addEventListener('load', onDone)
          img.addEventListener('error', onDone)
        }),
    ),
  )

  // Bound the wait: a stalled resource must never hang the download. Whichever
  // settles first — all resources loaded, or the timeout — triggers printing.
  const RESOURCE_WAIT_TIMEOUT_MS = 3000
  let timeoutId: ReturnType<typeof globalThis.setTimeout> | undefined
  const waitForResources = Promise.race([
    Promise.all([waitForStylesheets, waitForImages]),
    new Promise<void>((resolve) => {
      timeoutId = globalThis.setTimeout(resolve, RESOURCE_WAIT_TIMEOUT_MS)
    }),
  ])

  waitForResources
    .catch(() => {
      // If waiting fails, fall through and attempt to print anyway
    })
    .finally(() => {
      // Cancel the timeout if the resources won the race, so it doesn't linger.
      globalThis.clearTimeout(timeoutId)

      const contentWindow = iframe.contentWindow

      if (!contentWindow) {
        iframe.remove()
        return
      }

      // The browser's "Save as PDF" dialog derives its suggested filename from
      // the TOP document's title (not the iframe's), so temporarily swap it to
      // the requested title and restore it once printing finishes.
      const previousDocumentTitle = document.title

      if (options?.title) {
        document.title = options.title
      }

      const cleanup = (): void => {
        if (options?.title) {
          document.title = previousDocumentTitle
        }
        iframe.remove()
      }

      // Clean up when printing finishes, with a fallback timeout
      const fallbackTimeout = globalThis.setTimeout(cleanup, 10_000)

      contentWindow.onafterprint = () => {
        globalThis.clearTimeout(fallbackTimeout)
        cleanup()
      }

      contentWindow.print()
    })
}
