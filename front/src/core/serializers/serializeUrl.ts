export const serializeUrl = (url: string) => {
  try {
    return new URL(url).href
  } catch {
    return null
  }
}
