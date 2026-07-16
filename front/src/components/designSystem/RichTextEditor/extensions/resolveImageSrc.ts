/**
 * Resolves an image node's `src` for rendering.
 * - blob id present in `images` → its signed URL (empty value → null, i.e. nothing)
 * - http(s)/data URL → verbatim (legacy pasted-URL image, no migration)
 * - unknown id → null (render nothing: never a broken image, never the raw id)
 */
export const resolveImageSrc = (
  src: string | null | undefined,
  images: Record<string, string>,
): string | null => {
  if (!src) return null
  if (Object.hasOwn(images, src)) return images[src] || null
  if (/^(https?:|data:)/i.test(src)) return src
  return null
}
