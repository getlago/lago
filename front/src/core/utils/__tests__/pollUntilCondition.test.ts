import { pollUntilCondition } from '../pollUntilCondition'

describe('pollUntilCondition', () => {
  beforeEach(() => {
    jest.useFakeTimers()
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  it('should wait for pollInterval before making the first fetch call', async () => {
    const fetchFn = jest.fn().mockResolvedValue('success')
    const conditionFn = jest.fn().mockReturnValue(true)

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 3,
      pollInterval: 1000,
    })

    // fetchFn should not be called immediately
    expect(fetchFn).not.toHaveBeenCalled()

    // Advance timer by 999ms - still should not be called
    await jest.advanceTimersByTimeAsync(999)
    expect(fetchFn).not.toHaveBeenCalled()

    // Advance timer by 1ms more (total 1000ms) - now it should be called
    await jest.advanceTimersByTimeAsync(1)
    expect(fetchFn).toHaveBeenCalledTimes(1)

    await pollPromise
  })

  it('should stop polling when condition is met', async () => {
    const fetchFn = jest.fn().mockResolvedValue('done')
    const conditionFn = jest.fn().mockReturnValue(true)

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 3,
      pollInterval: 1000,
    })

    await jest.advanceTimersByTimeAsync(1000)

    const result = await pollPromise

    expect(fetchFn).toHaveBeenCalledTimes(1)
    expect(result).toEqual({ data: 'done', conditionMet: true, aborted: false })
  })

  it('should continue polling until condition is met', async () => {
    const fetchFn = jest
      .fn()
      .mockResolvedValueOnce('pending')
      .mockResolvedValueOnce('pending')
      .mockResolvedValueOnce('success')

    const conditionFn = jest.fn((data) => data === 'success')

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 5,
      pollInterval: 1000,
    })

    // First poll
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(1)
    expect(conditionFn).toHaveBeenCalledWith('pending')

    // Second poll
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(2)

    // Third poll - condition met
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(3)

    const result = await pollPromise

    expect(result).toEqual({ data: 'success', conditionMet: true, aborted: false })
  })

  it('should stop after maxAttempts if condition is never met', async () => {
    const fetchFn = jest.fn().mockResolvedValue('pending')
    const conditionFn = jest.fn().mockReturnValue(false)

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 3,
      pollInterval: 1000,
    })

    // Advance through all 3 attempts
    await jest.advanceTimersByTimeAsync(3000)

    const result = await pollPromise

    expect(fetchFn).toHaveBeenCalledTimes(3)
    expect(result).toEqual({ data: null, conditionMet: false, aborted: false })
  })

  it('should respect different poll intervals', async () => {
    const fetchFn = jest.fn().mockResolvedValue('data')
    const conditionFn = jest.fn().mockReturnValue(true)

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 3,
      pollInterval: 500,
    })

    // Should not call before 500ms
    await jest.advanceTimersByTimeAsync(499)
    expect(fetchFn).not.toHaveBeenCalled()

    // Should call at 500ms
    await jest.advanceTimersByTimeAsync(1)
    expect(fetchFn).toHaveBeenCalledTimes(1)

    await pollPromise
  })

  it('should wait between each poll attempt', async () => {
    const fetchFn = jest.fn().mockResolvedValue('pending')
    const conditionFn = jest.fn().mockReturnValue(false)

    const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
      maxAttempts: 3,
      pollInterval: 1000,
    })

    // First attempt after 1000ms
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(1)

    // Second attempt after another 1000ms (total 2000ms)
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(2)

    // Third attempt after another 1000ms (total 3000ms)
    await jest.advanceTimersByTimeAsync(1000)
    expect(fetchFn).toHaveBeenCalledTimes(3)

    await pollPromise
  })

  describe('cancellation with AbortSignal', () => {
    it('should not make any fetch calls if aborted before first poll', async () => {
      const fetchFn = jest.fn().mockResolvedValue('data')
      const conditionFn = jest.fn().mockReturnValue(true)
      const abortController = new AbortController()

      const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
        maxAttempts: 3,
        pollInterval: 1000,
        signal: abortController.signal,
      })

      // Abort before the first interval completes
      await jest.advanceTimersByTimeAsync(500)
      abortController.abort()

      // Advance past the first interval
      await jest.advanceTimersByTimeAsync(500)

      const result = await pollPromise

      expect(fetchFn).not.toHaveBeenCalled()
      expect(result).toEqual({ data: null, conditionMet: false, aborted: true })
    })

    it('should stop polling when aborted during wait', async () => {
      const fetchFn = jest.fn().mockResolvedValue('pending')
      const conditionFn = jest.fn().mockReturnValue(false)
      const abortController = new AbortController()

      const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
        maxAttempts: 5,
        pollInterval: 1000,
        signal: abortController.signal,
      })

      // First poll completes
      await jest.advanceTimersByTimeAsync(1000)
      expect(fetchFn).toHaveBeenCalledTimes(1)

      // Abort during second wait (after 500ms of the second interval)
      await jest.advanceTimersByTimeAsync(500)
      abortController.abort()

      // Complete the remaining time
      await jest.advanceTimersByTimeAsync(500)

      const result = await pollPromise

      // Should have only made 1 call before abort
      expect(fetchFn).toHaveBeenCalledTimes(1)
      expect(result).toEqual({ data: null, conditionMet: false, aborted: true })
    })

    it('should stop polling when aborted between polls', async () => {
      const fetchFn = jest.fn().mockResolvedValue('pending')
      const conditionFn = jest.fn().mockReturnValue(false)
      const abortController = new AbortController()

      const pollPromise = pollUntilCondition(fetchFn, conditionFn, {
        maxAttempts: 5,
        pollInterval: 1000,
        signal: abortController.signal,
      })

      // Complete 2 polls
      await jest.advanceTimersByTimeAsync(2000)
      expect(fetchFn).toHaveBeenCalledTimes(2)

      // Abort before third poll starts
      abortController.abort()

      // Try to advance more time
      await jest.advanceTimersByTimeAsync(3000)

      const result = await pollPromise

      // Should have stopped at 2 calls
      expect(fetchFn).toHaveBeenCalledTimes(2)
      expect(result).toEqual({ data: null, conditionMet: false, aborted: true })
    })
  })
})
