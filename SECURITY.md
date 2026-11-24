# Security Policy

## 1. Introduction

We take the security of our software, infrastructure, and users seriously. We welcome responsible security research from the community and appreciate reports that help us identify and address genuine security vulnerabilities.

This policy establishes the guidelines for conducting security research and submitting vulnerability reports to our organization.

By participating in security research against our projects, you agree to follow the guidelines outlined below.

## 2. Scope

Our security vulnerability disclosure program covers security vulnerabilities in software and components that are explicitly maintained by this organization.

### In scope

The following are eligible for security reports:

- Source code maintained within the repositories explicitly covered by this policy.
- Security-sensitive functionality implemented by our software.
- Authentication and authorization mechanisms.
- Access control vulnerabilities, including privilege escalation and improper permission enforcement.
- Cryptographic implementations and security-sensitive configuration.
- Input validation vulnerabilities that result in demonstrable security impact.
- Injection vulnerabilities, including SQL injection, command injection, and cross-site scripting, where applicable.
- Remote code execution vulnerabilities.
- Exposure of sensitive information, credentials, secrets, or private data resulting from a vulnerability in our code.
- Insecure default configurations that introduce a meaningful security risk.
- Vulnerabilities in application logic that compromise the confidentiality, integrity, or availability of protected resources.

### Out of scope

The following are generally not eligible for security reports:

- Vulnerabilities in third-party dependencies that cannot be demonstrated to introduce a security vulnerability in our software.
- Vulnerabilities in third-party services, infrastructure, or platforms that we do not own or control.
- Vulnerabilities that require unrealistic assumptions or privileged access without demonstrating a meaningful security boundary violation.
- Theoretical vulnerabilities without a demonstrable security impact.
- Reports based solely on automated scanner output, static analysis warnings, or AI-generated security claims without independent validation.
- Best-practice recommendations or general security hardening suggestions without an identifiable vulnerability.
- Denial-of-service findings requiring excessive resource consumption or disruptive testing.
- Social engineering, phishing, physical attacks, or attacks against individual maintainers or users.
- Missing security headers, cookie attributes, or other configuration recommendations without a demonstrated security consequence.
- Reports concerning outdated dependencies without evidence of exploitability in our implementation or deployment.
- Issues already publicly documented or previously reported, unless new evidence demonstrates a materially different security impact.

We reserve the right to determine whether a finding falls within the scope of this policy.

## 3. Requirements for a valid security finding

We prioritize actionable reports that demonstrate an actual security vulnerability rather than hypothetical risks or unverified claims.

A valid report must establish the following:

### 3.1 Identifiable vulnerability

The report must identify a specific security weakness in code or functionality maintained by our organization.

Researchers should identify the affected component, file, function, API endpoint, or relevant implementation wherever possible.

### 3.2 Reproducibility

The vulnerability must be reproducible.

Reports must include clear, step-by-step instructions that allow our security team to independently reproduce the issue.

These instructions should include:

- The affected repository and component.
- The affected version, release, commit, or branch.
- Relevant environment and configuration details.
- Any prerequisites or required permissions.
- Exact steps to trigger the vulnerability.
- The expected behavior.
- The actual observed behavior.

Reports that cannot be independently reproduced may be closed or returned for additional information.

### 3.3 Proof of concept (PoC)

A working proof of concept is required for reports claiming exploitable security vulnerabilities.

The PoC must demonstrate the vulnerability in a controlled environment without compromising third-party systems, accessing real user data, or causing disruption.

Acceptable PoC formats include:

- Minimal scripts demonstrating the vulnerability.
- HTTP requests and corresponding responses.
- Test cases demonstrating unauthorized behavior.
- Screenshots or recordings that supplement reproducible technical steps.
- Minimal code demonstrating the vulnerable behavior.
- A demonstration using a locally deployed instance or isolated test environment.

A PoC should be focused on demonstrating the vulnerability, not causing damage or maximizing its impact.

### 3.4 Supporting evidence

Reports must include sufficient technical evidence to substantiate the finding.

Evidence may include:

- Reproduction steps.
- PoC code or test cases.
- Relevant request/response pairs.
- Logs or error messages.
- Screenshots or recordings.
- References to affected source code.
- An explanation of the security boundary being violated.

Evidence must be collected in a controlled environment and must not contain actual user credentials, private information, or other sensitive data.

## 4. AI-generated reports and automated security findings

We recognize that researchers may use AI-assisted tools, automated scanners, static analysis, and other automated technologies during security research.

However, automated output alone does not constitute a valid vulnerability report.

The use of AI-generated analysis or automated tooling does not replace the requirement for independent technical validation.

Reports consisting primarily of the following will generally be considered insufficient:

- AI-generated vulnerability descriptions without independent verification.
- Hypothetical exploit scenarios without a working PoC.
- Scanner output without an explanation of exploitability.
- Generic recommendations copied from security tools.
- Claims of critical vulnerabilities without demonstrated impact.
- References to vulnerable code patterns without showing how they can be exploited in practice.

Researchers are responsible for validating their findings and ensuring that submitted reports accurately reflect the behavior of the affected software.

We reserve the right to close reports that contain unsubstantiated or unverifiable claims.

## 5. Rules of engagement

To protect our users, maintainers, and infrastructure, all security research must be conducted responsibly.

Researchers must:

- Test only assets and components explicitly covered by this policy.
- Prefer local, isolated, or researcher-controlled test environments.
- Avoid accessing, modifying, deleting, or disclosing other users' data.
- Avoid disrupting services or degrading system availability.
- Avoid conducting denial-of-service or resource-exhaustion testing.
- Avoid social engineering or attacks against maintainers and users.
- Avoid persistence, lateral movement, or unnecessary privilege escalation.
- Stop testing immediately if sensitive information or unintended access to third-party data is encountered.
- Keep vulnerability details confidential until coordinated disclosure has been agreed upon.
- Provide sufficient information to allow maintainers to investigate and address the issue.

Researchers must not exploit vulnerabilities beyond what is reasonably necessary to demonstrate their existence and security impact.

## 6. Reporting requirements

Email is the sole reporting channel for security findings. Send an email to [security@getlago.com](mailto:security@getlago.com).

### Response timelines and disclosure

We acknowledge receipt of vulnerability reports within 3 business days and aim to provide an initial assessment within 5 business days. We request that researchers allow up to 90 days for remediation prior to any public disclosure, coordinated in agreement with our security team.

Please do not submit vulnerability details through public GitHub issues, pull requests, discussions, or other public communication channels.

## 7. Required report information

A submission must include:

- **Vulnerability title**: A concise description of the identified issue.
- **Affected component**: Repository, file, function, endpoint, or relevant implementation.
- **Affected version**: Release, commit, or branch where the vulnerability exists.
- **Vulnerability description**: A technical explanation of the underlying security weakness.
- **Reproduction steps**: Clear, sequential instructions to reproduce the finding.
- **Proof of concept**: A working demonstration or test case.
- **Security impact**: A description of what an attacker can achieve and which security properties are affected.
- **Prerequisites**: Required access, permissions, configuration, or attacker capabilities.
- **Supporting evidence**: Relevant logs, screenshots, requests, responses, or other technical artifacts.
- **Suggested remediation**: Optional recommendations for addressing the vulnerability.

Reports missing essential information may be returned for clarification or closed if the finding cannot be validated.
