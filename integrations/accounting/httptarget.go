package accounting

import (
	"fmt"
	"io"
	"net/http"
)

// PostError describes a non-2xx response from an accounting API. Permanent==true
// means a retry won't help (a 4xx other than 429), so the caller can route the
// event to a dead-letter queue instead of retrying forever.
type PostError struct {
	Target     string
	StatusCode int
	Permanent  bool
	Body       string
}

func (e *PostError) Error() string {
	return fmt.Sprintf("%s: post failed with HTTP %d (permanent=%v): %s",
		e.Target, e.StatusCode, e.Permanent, e.Body)
}

func permanentStatus(code int) bool {
	return code >= 400 && code < 500 && code != http.StatusTooManyRequests
}

// doJSONRequest executes req and classifies the response, shared by every HTTP
// accounting target:
//   - 2xx           -> nil (booked)
//   - 409 Conflict  -> nil (the record for this idempotency key already exists;
//     an earlier delivery won the race - exactly-once holds)
//   - anything else -> *PostError tagged with the target name
func doJSONRequest(target string, client *http.Client, req *http.Request) error {
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("%s: request: %w", target, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))

	switch {
	case resp.StatusCode >= 200 && resp.StatusCode < 300:
		return nil
	case resp.StatusCode == http.StatusConflict:
		return nil // already booked under this idempotency key
	default:
		return &PostError{
			Target:     target,
			StatusCode: resp.StatusCode,
			Permanent:  permanentStatus(resp.StatusCode),
			Body:       string(body),
		}
	}
}
