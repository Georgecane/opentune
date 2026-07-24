# Security Policy

OpenTune is an early-stage, open-source Digital Audio Workstation. Security issues can affect the native Zig audio engine, the C ABI, the C#/.NET application, the Avalonia user interface, project files, plugin loading and the build or release infrastructure.

We appreciate responsible security research and coordinated disclosure.

---

## Supported Versions

OpenTune is currently in pre-alpha development. During this phase, security support is provided on a best-effort basis.

| Version or branch | Security support |
|---|---|
| `main` | Supported; fixes are prioritized here |
| Latest stable release | Supported when available |
| Older pre-release versions | Best effort only |
| Unmodified third-party plugins | Not maintained by OpenTune |

Because the project is pre-alpha, users should not use OpenTune with sensitive or production-critical data without appropriate backups and isolation.

---

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues, pull requests or public discussions.**

### Preferred method

Submit a private report through GitHub Security Advisories for this repository:

```text
https://github.com/Georgecane/OpenTune/security/advisories/new
```

Replace `Georgecane` with the actual GitHub organization or account before publishing this file.

### Fallback method

If private GitHub Security Advisories are unavailable, contact the maintainers at:

```text
zenwhats@gmail.com
```

## What to Include in a Report

A useful report should include as much of the following information as possible:

- A clear description of the vulnerability
- The affected component
- The affected version, branch or commit
- The operating system and CPU architecture
- Build configuration and compiler/runtime versions
- Reproduction steps
- A minimal proof of concept, if available
- Expected and actual behavior
- Security impact
- Whether the issue can be triggered remotely, locally or only with user interaction
- Whether the issue requires a malicious project, plugin, sample or content package
- Any suggested mitigation or fix
- Whether you intend to publish the issue independently

For crashes, include a sanitized stack trace or crash log when possible.

For project-file or parser vulnerabilities, provide a minimal test file instead of the original user file whenever possible.

---

## Response Process

The maintainers will generally follow this process:

1. Acknowledge receipt of the report.
2. Reproduce and validate the issue.
3. Assess severity and affected versions.
4. Identify mitigations and affected release artifacts.
5. Prepare and test a fix.
6. Publish a coordinated security advisory when appropriate.
7. Credit the reporter if they agree to be credited.

Our target response times are:

| Action | Target |
|---|---|
| Initial acknowledgement | Within 3 business days |
| Initial triage | Within 7 business days |
| Status update | At least every 14 days while active |
| Fix timeline | Depends on severity, complexity and affected platforms |

These are targets rather than guarantees, especially while OpenTune is maintained by a small or volunteer team.

---

## Severity Guidelines

Severity will be assessed using practical impact and exploitability. CVSS may be used as a reference, but it will not be the only factor.

### Critical

Examples include:

- Remote code execution without meaningful user interaction
- Arbitrary code execution through a normal project-opening workflow
- A release or build-system compromise affecting distributed binaries
- Theft or exposure of sensitive maintainer credentials

### High

Examples include:

- Code execution through a malicious project, archive or plugin under realistic conditions
- Sandbox escape, once plugin sandboxing is available
- Arbitrary file write outside an intended project directory
- Significant privilege escalation
- A reproducible memory-safety issue reachable through untrusted input

### Medium

Examples include:

- Denial of service through a malformed project or media file
- Path traversal limited to a controlled project operation
- Sensitive local information disclosure
- A vulnerability requiring unusual configuration or extensive user interaction

### Low

Examples include:

- Minor information disclosure
- Hardening issues with limited practical impact
- Unsafe defaults that do not directly expose sensitive data
- Documentation or configuration issues with a narrow security effect

---

## Important Security Boundaries

### Native Plugins Are Executable Code

A native audio plugin can execute arbitrary code with the privileges of the OpenTune process.

Until plugin sandboxing is implemented and independently reviewed, users should only install plugins from sources they trust. OpenTune cannot guarantee the safety of a third-party plugin merely because the plugin appears in a plugin browser.

This applies to native formats such as CLAP, VST3, LV2 and other dynamically loaded plugin formats.

### Project Files Are Untrusted Input

OpenTune may load projects, media references, presets, automation data and content packages from external sources.

Project parsers must treat all external files as untrusted and must defend against:

- Buffer overflows
- Integer overflows
- Excessive memory allocation
- Malformed metadata
- Path traversal
- Symbolic-link surprises
- Archive extraction attacks
- Denial-of-service inputs
- Unsafe deserialization

### C ABI Boundaries Must Be Validated

The Zig engine and .NET application communicate through a C-compatible ABI.

All ABI entry points must validate:

- ABI version
- Struct size
- Pointer validity
- Buffer length
- Integer ranges
- Channel counts
- Sample rates
- Block sizes
- Ownership and lifetime rules
- Nullability and optional values

No managed object, Zig allocator, slice or internal pointer should cross the ABI boundary without an explicit and documented ownership model.

### Real-Time Audio Safety

Real-time audio safety is primarily a reliability requirement, but violations can also create denial-of-service conditions or unstable process behavior.

The real-time audio path must not perform:

- Unbounded allocation
- Blocking I/O
- Network access
- UI calls
- Calls into the .NET runtime
- Unbounded logging
- Untrusted plugin discovery
- File-system operations

---

## Secure Development Practices

OpenTune aims to use the following practices as the project matures:

### Zig Engine

- Debug safety checks during development
- AddressSanitizer and UndefinedBehaviorSanitizer where supported
- Fuzzing for project, media and plugin metadata parsers
- Strict integer and buffer-bound checks
- Deterministic offline rendering tests
- Minimal and reviewed ABI surface
- Thread-safety and lifetime documentation
- No unaudited unsafe FFI shortcuts

### C#/.NET Application

- Nullable reference types enabled
- Safe P/Invoke or `LibraryImport` declarations
- Explicit marshaling definitions
- No dynamic native calls from untrusted input
- Dependency vulnerability checks
- Static analysis and compiler warnings enabled
- Secure temporary-file handling
- Careful path normalization and validation

### Dependencies

Maintainers should periodically review dependencies using tools such as:

```bash
dotnet list package --vulnerable --include-transitive
```

Dependency updates should be reviewed for:

- Known vulnerabilities
- License compatibility
- Native code changes
- Build-script behavior
- Newly introduced network access
- Maintenance status

Automated dependency update tools may be used, but updates must still pass platform, audio and interoperability tests.

### Releases

As the project approaches public stable releases, OpenTune intends to add:

- Reproducible build documentation
- Checksums for release artifacts
- Signed release packages
- Software Bill of Materials (SBOM)
- Hardened CI permissions
- Protected release branches
- Build provenance information

---

## Privacy and Telemetry

OpenTune should not collect personal data or telemetry by default.

Any future diagnostic, update-checking or telemetry feature must be:

- Disabled by default or clearly disclosed
- Documented in the privacy policy
- Configurable by the user
- Free of project audio and private content uploads unless explicitly requested
- Designed to minimize personally identifiable information

Credentials, tokens and private project data must never be written to logs.

---

## Coordinated Disclosure

We ask reporters to allow reasonable time for investigation and remediation before public disclosure.

When a fix is available, the maintainers may publish:

- A security advisory
- Affected versions
- Fixed versions or commits
- Impact and severity
- Mitigation instructions
- Credit for the reporter, with permission

We will not intentionally disclose a reporter’s identity without permission, except where legally required.

If a vulnerability is being actively exploited or cannot reasonably remain private, the maintainers will work with the reporter on an accelerated disclosure timeline.

---

## Out of Scope

The following are generally outside the scope of the OpenTune security policy:

- Vulnerabilities in third-party plugins that are not caused by OpenTune
- Security issues in third-party operating systems, audio drivers or DAWs
- Bugs requiring a user to execute a malicious binary manually
- Social engineering attacks against users or maintainers
- Denial of service caused only by unsupported hardware or drivers
- Reports without a security impact
- Publicly known vulnerabilities in dependencies without an OpenTune-specific impact

However, dependency vulnerabilities should still be reported when they affect OpenTune’s distributed builds or create a realistic risk to users.

---

## Safe Harbor for Good-Faith Research

The OpenTune maintainers will not pursue legal action against security researchers who:

- Act in good faith
- Avoid accessing or modifying data that does not belong to them
- Avoid degrading service availability
- Avoid persistent access
- Avoid public disclosure before reasonable coordination
- Report findings promptly through the channels described above
- Stop testing after confirming the vulnerability

This safe-harbor statement does not grant permission to violate third-party services, licenses or applicable law.