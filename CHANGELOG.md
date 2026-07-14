# Changelog

## July 2026

### Added

- **GuardedCalloutBuilder** — the guardrail engine now lives in its own MCP-independent module. `GuardedCalloutBuilder` is a decorator that mirrors the CalloutBuilder API and enforces a guardrail chain (authentication, allowed methods, endpoint patterns, and pluggable custom guardrails via the `CalloutGuardrail` strategy interface) configured per Named Credential in the `Named_Credentials_Configuration__mdt` custom metadata type. Any Apex callout can opt into enforcement by swapping `CalloutBuilder` for `GuardedCalloutBuilder` ([guardedCalloutBuilder](force-app/main/guardedCalloutBuilder/classes/README.md))
- **Named Credentials MCP** — new module exposing three Salesforce-hosted MCP tools, `listCredentials` (which credentials exist and whether each is authenticated), `describe` (how to call one credential), and `sendRequest` (guarded HTTP request), so AI agents (and Flows/Agentforce) can make callouts through the org's Named Credentials without ever handling a token. The tools are thin invocable wrappers over the `GuardedCalloutBuilder` module above ([namedCredentialsMcp](force-app/main/namedCredentialsMcp/README.md))

### Changed

- **Guardrail classes extracted from `ncMcp_`** — the guardrail engine moved out of `namedCredentialsMcp` into the new `guardedCalloutBuilder` module and dropped the MCP-branded prefix: `ncMcp_GuardedCalloutBuilder` → `GuardedCalloutBuilder`, `ncMcp_Guardrail` → `CalloutGuardrail`, `ncMcp_AuthenticationGuardrail`/`ncMcp_MethodGuardrail`/`ncMcp_EndpointGuardrail`/`ncMcp_ExampleGuardrail` → `Callout*Guardrail`, `ncMcp_Config` → `GuardedCalloutConfig`, and `ncMcp_Exception` → `GuardedCalloutException`. The `Named_Credentials_Configuration__mdt` type keeps its name. The MCP tool classes (`ncMcp_*Tool`) are unchanged and now depend on the new module
- **`CalloutBuilderException` HTTP context** — the exception thrown on a failed response now carries `code` (HTTP status code) and `status` (HTTP status text) fields, so catch blocks no longer need a reference to the builder to branch on the status code; both fields are null when the exception is thrown before a callout, e.g. during builder validation ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **ConnectApiAdapter credential methods** — `getCredentialAuthenticationUrl()` returns the URL a user visits to authorize a credential (OAuth flow); `getNamedCredential()` and `getExternalCredential()` expose full Named/External Credential details ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))

### Changed

- **API Version** — Promoted to 67
- **ConnectApiAdapter sharing** — declared `inherited sharing` instead of `with sharing`, so the adapter runs in the caller's sharing context ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))

## May 2026

### Added

- **ViciousMockBase** — new base class for Vicious mock implementations, extracting shared logic from `ViciousMockery` to reduce boilerplate in subclasses ([ViciousMockBase.cls](force-app/main/viciousMockery/classes/ViciousMockBase.cls))
- **Mock Overrides** — `CalloutBuilder` now supports per-test mock overrides, enabling tests to swap individual responses without replacing the whole mock ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **CalloutHexFormBuilder** — `writeJsonParameter()`, `writeJsonParameters()`, and `writeFile()` (blob) methods for multipart form construction ([CalloutHexFormBuilder.cls](force-app/main/calloutBuilder/classes/CalloutHexFormBuilder.cls))
- **`withFile(CalloutHexFormBuilder)`** overload on `CalloutBuilder` for attaching hex-encoded file parts to a callout ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))

### Changed

- **`validateResponse()`** — expanded validation logic with improved error messaging; tests updated to cover new cases ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **ViciousMockBase naming** — improved method and variable names across `ViciousMockery`
- **MIME type** `image/jpg` replaced with `image/jpeg` ([MimeType.cls](force-app/main/calloutBuilder/classes/MimeType.cls))

### Documentation

- **Root README** — expanded with library overview, feature highlights, and usage guidance
- **CalloutBuilder README** — described mock overrides and error handling
- **ViciousMockery README** — expanded usage guide covering `ViciousMockBase` subclassing and mock overrides
