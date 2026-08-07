# Changelog

## August 2026

### Added

- **`CalloutBuilder.withResponseSanitizer()` / `withResponseSanitizers()`** — a callout can carry a chain of `CalloutResponseSanitizer` transformations that rewrite a validated response before the caller sees it, or block it by throwing `CalloutResponseSanitizerException`. The retrier, the error path, and debug logging still see the raw response; a sanitizer that tries to execute its own builder is rejected ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls), [CalloutResponseSanitizer.cls](force-app/main/calloutBuilder/classes/CalloutResponseSanitizer.cls), [CalloutResponseSanitizerException.cls](force-app/main/calloutBuilder/classes/CalloutResponseSanitizerException.cls))
- **`CalloutJsonPathSanitizer`** — shipped sanitizer removing JSON nodes matched by bracket-path criteria (`'results[folder][id]' => restricted ids`, a `List` value meaning any-of); a match removes the nearest enclosing list item, entries combine with `Match.ANY_ENTRY` or `Match.ALL_ENTRIES`, and a non-JSON body fails closed ([CalloutJsonPathSanitizer.cls](force-app/main/calloutBuilder/classes/CalloutJsonPathSanitizer.cls))

## July 2026

### Added

- **`CalloutBuilder.withGuardrail()` / `withGuardrails()`** — a callout can carry a chain of `CalloutGuardrail` checks that run before the request is constructed and block it by throwing `CalloutGuardrailException`. A guardrail that tries to execute the builder it is inspecting is rejected ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls), [CalloutGuardrail.cls](force-app/main/calloutBuilder/classes/CalloutGuardrail.cls), [CalloutGuardrailException.cls](force-app/main/calloutBuilder/classes/CalloutGuardrailException.cls))
- **ConnectApiAdapter credential methods** — `getCredentialAuthenticationUrl()` returns the URL a user visits to authorize a credential (OAuth flow); `getNamedCredential()` and `getExternalCredential()` expose full Named/External Credential details ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))
- **ConnectApiAdapter single-parameter overloads** — `refreshToken()`, `isCredentialConfigured()`, and `getCredentialAuthenticationUrl()` now accept just the external credential api name and resolve its single principal (and authentication protocol) automatically; they throw `ConnectApiAdapterException` when the external credential doesn't have exactly one principal ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))
- **`ConnectApiAdapter.ConnectApiAdapterException`** — the exception the single-parameter overloads throw when an external credential cannot be retrieved, has other than exactly one principal, or exposes no authentication protocol ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))

### Changed

- **`CalloutBuilderException` HTTP context** — the exception thrown on a failed response now carries `code` (HTTP status code) and `status` (HTTP status text) fields, so catch blocks no longer need a reference to the builder to branch on the status code; both fields are null when the exception is thrown before a callout, e.g. during builder validation ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **`CalloutBuilder` is extensible** — the class is `virtual`, `withEndpoint`, `withMethod`, `withBody`, `withBlobBody`, and `getHttpResponse` are overridable, and `getEndpoint()`, `getHeaders()`, `getQueryParameters()` expose request state that previously had no read path. Every response variant funnels through `getHttpResponse()`, so a subclass overriding it observes every callout ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **Body precedence over query parameters** — a non-GET request carrying both a body and query parameters threw `ClassCastException` for any non-String body, and sent String bodies unserialized. The body now always wins and is serialized consistently, as the documentation already stated ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **Query string joining** — query parameters now extend an endpoint that already carries a query string with `&`, instead of emitting a second `?` ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **API Version** — Promoted to 67
- **ConnectApiAdapter sharing** — declared `inherited sharing` instead of `with sharing`, so the adapter runs in the caller's sharing context ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))
- **`getCalloutUrl()`** — returns null instead of throwing when the Named Credential cannot be retrieved ([ConnectApiAdapter.cls](force-app/main/connectApiAdapter/classes/ConnectApiAdapter.cls))

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
