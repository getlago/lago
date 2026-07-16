/**
 * Validates a host string without protocol (http/https).
 * Rejects values starting with http:// or https://.
 * Validates host format (domain or IP address).
 *
 * @param value - The host value to validate (must be a non-empty string)
 * @returns true if valid, false if invalid
 */
export const validateHostWithoutProtocol = (value: string): boolean => {
  const trimmedValue = value.trim()

  // Reject values starting with http:// or https://
  if (
    trimmedValue.toLowerCase().startsWith('http://') ||
    trimmedValue.toLowerCase().startsWith('https://')
  ) {
    return false
  }

  // Validate host format (domain or IP address)
  // More permissive hostname regex that allows multiple subdomains
  // Pattern: allows hostnames with multiple subdomains, hyphens, and valid TLDs
  // Examples: example.com, subdomain.example.com, test-domain.org, example.co.uk
  const hostnameRegex = /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/i

  // IPv4 regex
  const ipv4Regex =
    /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/

  // IPv6 regex (simplified - allows common formats)
  const ipv6Regex = /^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$/

  // Hostname with port (e.g., example.com:8080)
  const hostWithPortRegex = /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}:[0-9]+$/i

  // IP with port (e.g., 192.168.1.1:8080)
  const ipWithPortRegex =
    /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):[0-9]+$/

  const isValidHostname = hostnameRegex.test(trimmedValue)
  const isValidIpv4 = ipv4Regex.test(trimmedValue)
  const isValidIpv6 = ipv6Regex.test(trimmedValue)
  const isValidHostWithPort = hostWithPortRegex.test(trimmedValue)
  const isValidIpWithPort = ipWithPortRegex.test(trimmedValue)

  if (isValidHostname || isValidIpv4 || isValidIpv6 || isValidHostWithPort || isValidIpWithPort) {
    return true
  }

  return false
}
