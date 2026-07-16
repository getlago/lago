type PollOptions = {
  maxAttempts: number
  pollInterval: number
  signal?: AbortSignal
}

type PollResult<T> = {
  data: T | null
  conditionMet: boolean
  aborted: boolean
}

/**
 * Polls a function until a condition is met or max attempts is reached.
 * Waits for pollInterval before each poll attempt.
 *
 * @param fetchFn - Async function that fetches data
 * @param conditionFn - Function that checks if polling should stop (returns true to stop)
 * @param options - Polling options (maxAttempts, pollInterval, signal)
 * @returns Object with final data, whether condition was met, and whether it was aborted
 */
export async function pollUntilCondition<T>(
  fetchFn: () => Promise<T>,
  conditionFn: (data: T) => boolean,
  options: PollOptions,
): Promise<PollResult<T>> {
  const { maxAttempts, pollInterval, signal } = options

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    // Check if aborted before starting the wait (e.g., abort happened during previous fetchFn)
    if (signal?.aborted) {
      return { data: null, conditionMet: false, aborted: true }
    }

    await new Promise((resolve) => setTimeout(resolve, pollInterval))

    // Check if aborted during the wait to avoid unnecessary fetchFn call
    if (signal?.aborted) {
      return { data: null, conditionMet: false, aborted: true }
    }

    const data = await fetchFn()

    if (conditionFn(data)) {
      return { data, conditionMet: true, aborted: false }
    }
  }

  return { data: null, conditionMet: false, aborted: false }
}
