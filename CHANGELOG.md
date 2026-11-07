# Changelog

## November 2026

### Added

- **`CalloutXmlBuilder` / `CalloutXmlSerializable`** — build an XML request body whose elements keep the order they are added in; `withBody()` sends a `CalloutXmlSerializable` object as XML ([CalloutXmlBuilder.cls](force-app/main/calloutBuilder/classes/CalloutXmlBuilder.cls), [CalloutXmlSerializable.cls](force-app/main/calloutBuilder/classes/CalloutXmlSerializable.cls))

### Changed

- **API version 68.0** — up from 67.0 ([sfdx-project.json](sfdx-project.json))

## October 2026

### Added

- **`CalloutBuilder.withPathParameter()` / `withPathParameters()` / `getPathParameters()`** — `{name}` placeholders in the endpoint are filled with encoded values, each kept within one path segment ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **`ViciousMockBase.getRequests()` / `getLastRequest()` / `buildResponse()`** — a mock records the requests it answers; override `buildResponse()` to answer from the request ([ViciousMockBase.cls](force-app/main/viciousMockery/classes/ViciousMockBase.cls))
- **Email MIME types** — `MimeType` maps `eml` and `msg` ([MimeType.cls](force-app/main/calloutBuilder/classes/MimeType.cls))
- **`CalloutBuilderException.getError()`** — returns the parsed `withErrorType()` error from a caught exception ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **XML bodies** — `withBody()` sends a `Dom.Document` as XML, `getXmlResponseBody()` returns the response as a `Dom.Document`, and `CalloutResponseSanitizer.sanitize(Dom.Document)` covers that form ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls), [CalloutResponseSanitizer.cls](force-app/main/calloutBuilder/classes/CalloutResponseSanitizer.cls))
- **XML responses** — `getTypedResponseBody()`, `getResponseBodyMap()` and `withErrorType()` read a response with an XML Content-Type as XML; `withResponseParser()` sets a custom `CalloutResponseParser` ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls), [CalloutResponseParser.cls](force-app/main/calloutBuilder/classes/CalloutResponseParser.cls), [CalloutJsonParser.cls](force-app/main/calloutBuilder/classes/CalloutJsonParser.cls))
- **`CalloutXmlParser`** — parses XML into a `Dom.Document` that keeps CDATA content, a `Map<String, Object>` or an Apex type; an element that occurs once is a List for an initialized List field or `withListElements()`; subclasses can override `toKey()` and `toValue()` ([CalloutXmlParser.cls](force-app/main/calloutBuilder/classes/CalloutXmlParser.cls))

### Changed

- **License** — apexlib is licensed under Apache 2.0 instead of MIT ([LICENSE](LICENSE))
- **Improved endpoint safety** ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **`getEndpoint()` / `constructFullEndpoint()`** — return the endpoint with placeholders resolved ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **`ViciousMockery.cast()`** — returns the `ViciousMockery` instance it registers ([ViciousMockery.cls](force-app/main/viciousMockery/classes/ViciousMockery.cls))
- **Multipart heap** — `CalloutHexFormBuilder` keeps one hex copy of each file, and files over 5 MB no longer fail with `StringException` ([CalloutHexFormBuilder.cls](force-app/main/calloutBuilder/classes/CalloutHexFormBuilder.cls))
- **File names without an extension** — `MimeType.getByFileNameWithExtension()` returns `application/octet-stream` instead of throwing ([MimeType.cls](force-app/main/calloutBuilder/classes/MimeType.cls))
- **String bodies** — sent as-is when the Content-Type is set and is not JSON, instead of as a quoted JSON string ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))
- **Default Content-Type** — when no Content-Type is set, the body type picks it instead of Salesforce's `application/x-www-form-urlencoded` ([CalloutBuilder.cls](force-app/main/calloutBuilder/classes/CalloutBuilder.cls))

  | Body | Content-Type |
  | --- | --- |
  | JSON | `application/json` |
  | `Dom.Document` | `application/xml` |
  | Blob | `application/octet-stream` |

- **Debug mode** — refactored into `CalloutDebug` ([CalloutDebug.cls](force-app/main/calloutBuilder/classes/CalloutDebug.cls))

## August 2026

### Added

- **`CalloutBuilder.withResponseSanitizer()` / `withResponseSanitizers()`** — `CalloutResponseSanitizer` subclasses mutate or block a validated response before the caller sees it — the `HttpResponse`, or the body parsed once for `getResponseBodyMap()` / `getTypedResponseBody()`; a form a subclass does not override is blocked, and `CalloutResponseSanitizerChain` runs several sanitizers as one ([CalloutResponseSanitizer.cls](force-app/main/calloutBuilder/classes/CalloutResponseSanitizer.cls), [CalloutResponseSanitizerChain.cls](force-app/main/calloutBuilder/classes/CalloutResponseSanitizerChain.cls))

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
