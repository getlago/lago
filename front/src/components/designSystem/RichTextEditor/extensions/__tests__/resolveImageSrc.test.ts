import { resolveImageSrc } from '../resolveImageSrc'

describe('resolveImageSrc', () => {
  it('resolves a blob id present in the images map to its signed URL', () => {
    expect(resolveImageSrc('blob-1', { 'blob-1': 'https://signed/blob-1' })).toBe(
      'https://signed/blob-1',
    )
  })

  it('passes an http(s) URL through verbatim (legacy pasted image)', () => {
    expect(resolveImageSrc('https://cdn.example.com/a.png', {})).toBe(
      'https://cdn.example.com/a.png',
    )
  })

  it('passes a data: URL through verbatim', () => {
    expect(resolveImageSrc('data:image/png;base64,AAAA', {})).toBe('data:image/png;base64,AAAA')
  })

  it('returns null for an unknown id (not in map, not a URL)', () => {
    expect(resolveImageSrc('blob-unknown', { 'blob-1': 'https://signed/blob-1' })).toBeNull()
  })

  it('returns null for empty/nullish src', () => {
    expect(resolveImageSrc(null, {})).toBeNull()
    expect(resolveImageSrc(undefined, {})).toBeNull()
    expect(resolveImageSrc('', {})).toBeNull()
  })

  it('returns null when the id is present but maps to an empty string', () => {
    expect(resolveImageSrc('blob-1', { 'blob-1': '' })).toBeNull()
  })
})
