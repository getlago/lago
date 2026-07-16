/**
 * Custom Jest Snapshot Serializer for MUI/Emotion
 *
 * Normalizes dynamic values that change between test runs:
 * - MUI React IDs: :r[hex]: -> :r-mui-id:
 * - Emotion CSS hashes: css-[hash]-Component -> css-hash-Component
 */

const MUI_ID_REGEX = /:r[0-9a-z]+:/g
const EMOTION_CSS_REGEX = /css-[a-z0-9]+-/g

const NORMALIZED_MUI_ID = ':r-mui-id:'
const NORMALIZED_CSS_PREFIX = 'css-hash-'

export default {
  test(val: unknown): boolean {
    if (typeof val !== 'string') return false

    // Reset regex lastIndex since we use global flag
    MUI_ID_REGEX.lastIndex = 0
    EMOTION_CSS_REGEX.lastIndex = 0

    return MUI_ID_REGEX.test(val) || EMOTION_CSS_REGEX.test(val)
  },

  serialize(val: string): string {
    return val
      .replace(MUI_ID_REGEX, NORMALIZED_MUI_ID)
      .replace(EMOTION_CSS_REGEX, NORMALIZED_CSS_PREFIX)
  },
}
