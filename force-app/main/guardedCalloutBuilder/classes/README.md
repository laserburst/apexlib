# GuardedCalloutBuilder

## Purpose

A guardrail-enforcing subclass of [CalloutBuilder](../../calloutBuilder/classes/CalloutBuilder.cls). It inherits the CalloutBuilder fluent API, but before any request leaves the org it loads a per-Named-Credential configuration and runs a chain of guardrails — authentication, allowed HTTP method, allowed endpoint pattern, and any custom guardrails you name. Any guardrail can block the request. Nothing is callable until an administrator activates a configuration record for the credential, and the defaults are conservative (GET only, no writes).

This module is independent of Named Credentials MCP: the MCP tools are one consumer of it, but any Apex callout can opt into guardrail enforcement by swapping `CalloutBuilder` for `GuardedCalloutBuilder`.

## Structure

1. [GuardedCalloutBuilder](GuardedCalloutBuilder.cls) - the core class. Extends CalloutBuilder and attaches the guardrail chain for its Named Credential. It is also the context object each guardrail inspects.
2. [CalloutGuardrail](../../calloutBuilder/classes/CalloutGuardrail.cls) - the strategy interface for a single check, part of the CalloutBuilder library. Implement it to add a custom rule.
3. [GuardrailsFactory](GuardrailsFactory.cls) - builds the chain for one configuration: the built-ins, then the custom classes it names.
4. [CalloutAuthenticationGuardrail](CalloutAuthenticationGuardrail.cls) - built-in: allows only a Named Credential authenticated for the running context. Also exposes `getStatus()`/`Status` so callers (e.g. discovery tools) can report readiness.
5. [CalloutMethodGuardrail](CalloutMethodGuardrail.cls) - built-in: allows only the HTTP methods in `allowedMethods` (default GET).
6. [CalloutEndpointGuardrail](CalloutEndpointGuardrail.cls) - built-in: the path must match an `allowedEndpointPatterns` entry (default `*`); `..` traversal is always rejected.
7. [CalloutExampleGuardrail](CalloutExampleGuardrail.cls) - copy-ready reference custom guardrail: blocks any body that appears to contain a credential.
8. [GuardedCalloutConfig](GuardedCalloutConfig.cls) - loads and parses `Named_Credentials_Configuration__mdt`, applying safe defaults.

The built-in chain runs in a fixed order — authentication → allowed method → allowed endpoint → custom guardrails (in listed order).

Each class throws its own inner exception — `GuardedCalloutBuilder.GuardedCalloutBuilderException` for invalid builder input, `GuardedCalloutConfig.GuardedCalloutConfigException` for configuration problems, `GuardrailsFactory.GuardrailsFactoryException` for an unusable custom guardrail class. Guardrails themselves throw [CalloutGuardrailException](../../calloutBuilder/classes/CalloutGuardrailException.cls). (HTTP status ≥ 400 raises `CalloutBuilder.CalloutBuilderException` instead.)

## Configuration

Guardrails live in the **Named Credentials Configuration** custom metadata type (`Named_Credentials_Configuration__mdt`), one record per Named Credential:

| Field | Purpose |
| --- | --- |
| `Named_Credentials_Developer_Name__c` | DeveloperName of the target Named Credential (Text 255, so it is not limited by the 40-char record name). |
| `Is_Active__c` | Only active records are considered. |
| `Is_Test__c` | Reserved for this package's own test records; leave unchecked for real configurations. |
| `Configuration__c` | The JSON below. |

### `Configuration__c` JSON

```jsonc
{
  "description": "OpenAI Platform REST API",                       // required; a human/agent-readable summary
  "apiDocsUrl": "https://platform.openai.com/docs/api-reference",  // optional; a reference link
  "allowedMethods": ["GET", "POST"],      // optional; DEFAULT ["GET"] — writes and DELETE are opt-in
  "allowedEndpointPatterns": ["/v1/*"],   // optional; DEFAULT ["*"]; "*" matches any characters, including "/"
  "guardrails": ["MyCustomGuardrail"]     // optional; custom CalloutGuardrail class names, run after the built-ins
}
```

Defaults are conservative: with no `allowedMethods`, only `GET` is permitted; with no `allowedEndpointPatterns`, any path is permitted. Endpoint patterns are matched against the path only (the query string is ignored), and paths containing a `..` segment are always rejected.

### Example record

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <label>OpenAI</label>
    <protected>false</protected>
    <values>
        <field>Named_Credentials_Developer_Name__c</field>
        <value xsi:type="xsd:string">OpenAI_NC</value>
    </values>
    <values>
        <field>Is_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Configuration__c</field>
        <value xsi:type="xsd:string">{"description":"OpenAI Platform","apiDocsUrl":"https://platform.openai.com/docs/api-reference","allowedMethods":["GET","POST"],"allowedEndpointPatterns":["/v1/*"]}</value>
    </values>
</CustomMetadata>
```

## Examples (illustrative)

### Direct Apex usage

`GuardedCalloutBuilder` inherits the full CalloutBuilder API:

```Java (Apex)
HttpResponse response = new GuardedCalloutBuilder('OpenAI_NC')
    .withEndpoint('/v1/models')
    .withHeader('Accept', 'application/json')
    .getHttpResponse();
System.debug(response.getStatusCode() + ' ' + response.getBody());
```

A `String` passed to `withBody` or `withBlobBody` is sent verbatim, so guardrails inspect the bytes actually sent.

Apex has no covariant return types, so the inherited setters return `CalloutBuilder`. Assign the instance before chaining when you need the `GuardedCalloutBuilder` type:

```Java (Apex)
GuardedCalloutBuilder guarded = new GuardedCalloutBuilder('OpenAI_NC');
guarded.withEndpoint('/v1/models').withHeader('Accept', 'application/json');
```

### Custom guardrails

Guardrails are a strategy: implement [CalloutGuardrail](../../calloutBuilder/classes/CalloutGuardrail.cls) and add the class name to the `guardrails` list. They run after the built-in checks, in listed order. Throw `CalloutGuardrailException` to block; return normally to allow. Do not execute the builder from inside a guardrail — it throws.

`enforce` receives a `CalloutBuilder`; cast it to reach `getInspectableBody()` and `getConfig()`, whose `namedCredential` names the credential. The request itself comes from the inherited `getNcOrBaseUrl()`, `getEndpoint()`, `getMethod()`, `getHeaders()`, and `getQueryParameters()`.

[CalloutExampleGuardrail](CalloutExampleGuardrail.cls) is a copy-ready reference: it blocks any request whose body looks like it contains a credential.

```Java (Apex)
public with sharing class NoBulkDeleteGuardrail implements CalloutGuardrail {
    public void enforce(CalloutBuilder builder) {
        if (builder.getMethod() == 'DELETE' && builder.getEndpoint().contains('/bulk')) {
            throw new CalloutGuardrailException('Bulk delete is not permitted.');
        }
    }
}
```

The cast holds for any guardrail named in a configuration. Write against `CalloutBuilder` alone if the class must also work on a plain builder.

**Trust model:** the `guardrails` list runs admin-referenced Apex by name. Configuration records are protected metadata edited by administrators, so this is the same trust boundary as any admin-authored automation — but be deliberate about who can edit these records.

## Notes and limits

- The authentication check relies on ConnectApi, which reports on unified Named Credentials. Legacy Named Credentials may be reported as unauthenticated.
- ConnectApi is not executable in test context; [CalloutAuthenticationGuardrail](CalloutAuthenticationGuardrail.cls) exposes a `@TestVisible` status map so tests can simulate authentication states.
- Binary request bodies passed via `withBlobBody`/`withFile` are only inspectable when they decode as UTF-8 text; `getInspectableBody()` is null otherwise.
- Query parameters are inspectable via `getQueryParameters()`, including when they are form-encoded into a non-GET body.
