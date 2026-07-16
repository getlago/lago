# frozen_string_literal: true

module AdvisoryLockHelper
  def with_advisory_lock(lock_key, lock_released_after:)
    queue = Queue.new
    thread = start_lock_thread(queue, lock_key, lock_released_after)
    sleep 0.5
    yield
  ensure
    stop_thread(thread, queue) if thread
  end

  private

  def start_lock_thread(queue, lock_key, lock_released_after)
    Thread.start do
      start_time = Time.zone.now
      ApplicationRecord.transaction do
        ApplicationRecord.with_advisory_lock!(lock_key, transaction: true) do
          until queue.size > 0 || Time.zone.now - start_time > lock_released_after
            sleep 0.01
          end
        end
      end
    end
  end

  def stop_thread(thread, queue)
    queue.push(true)
    thread.join
  end
end
