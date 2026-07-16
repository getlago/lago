export enum FeatureFlags {
  SUPERSET_PERSISTENT_FILTERS = 'superset_persistent_filters',
}

const FF_KEY = 'featureFlags'

export const getEnableFeatureFlags = (): FeatureFlags[] => {
  const flags = localStorage.getItem(FF_KEY)

  return flags ? JSON.parse(flags) : []
}

export const listFeatureFlags = (): FeatureFlags[] => {
  return Object.values(FeatureFlags)
}

export const isFeatureFlagActive = (flag: FeatureFlags): boolean => {
  const flags = getEnableFeatureFlags()

  return flags.includes(flag)
}

export const setFeatureFlags = (flags: FeatureFlags[] | FeatureFlags | 'all') => {
  if (!flags) {
    flags = []
  }

  if (flags === 'all') {
    flags = listFeatureFlags()
  }

  if (!Array.isArray(flags)) {
    flags = [flags]
  }

  localStorage.setItem(FF_KEY, JSON.stringify(flags))

  return getEnableFeatureFlags()
}
