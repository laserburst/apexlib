# Named Credentials MCP

Exposes three Salesforce-hosted MCP tools so an AI agent can make HTTP callouts through the org's Named Credentials — **without ever seeing a token**. Salesforce injects authentication; every request passes through configurable guardrails. For the high-level architecture, see [How It Works](../README.md).

Because the tools are Apex invocable actions, they are equally usable from Flows and Agentforce, and the core is callable directly from Apex.

## Tools

| Tool | Class | Purpose |
| --- | --- | --- |
| `listCredentials` | [ncMcp_ListCredentialsTool](ncMcp_ListCredentialsTool.cls) | Lists the exposed credentials and whether each is ready to use (name, `isConfigured`, base URL, principal type). Unauthenticated credentials are included, so an agent can tell the user what is missing. |
| `describe` | [ncMcp_DescribeTool](ncMcp_DescribeTool.cls) | Returns how to use **one** credential: purpose, docs URL, base URL, allowed methods and endpoint patterns. Errors when the credential is unknown or not authenticated. |
| `sendRequest` | [ncMcp_SendRequestTool](ncMcp_SendRequestTool.cls) | Sends a guarded HTTP request through a Named Credential and returns the response. |

All three are thin invocable wrappers; the callout path runs through [ncMcp_GuardedCalloutBuilder](ncMcp_GuardedCalloutBuilder.cls), a decorator that mirrors the [CalloutBuilder](../../calloutBuilder/classes/CalloutBuilder.cls) API and enforces the guardrail chain.

## How it works

1. `listCredentials` returns every credential with an active configuration and its authentication status for the running user.
2. `describe` returns the usage contract for one credential: its purpose, docs URL, allowed methods, and endpoint patterns.
3. `sendRequest` builds a guarded callout. Before the request leaves the org, the decorator loads the credential's configuration and runs the guardrail chain:
   authentication → allowed method → allowed endpoint → any custom guardrails.
4. On success the response (status code, status text, body, headers) is returned. On an HTTP status ≥ 400 the callout raises `CalloutBuilder.CalloutBuilderException` (its message carries the response body); on a guardrail violation or bad input it raises `ncMcp_Exception`.

Nothing is usable by default. An API can be called only when an admin adds an active configuration record for it **and** the Named Credential is authenticated for the running user (per-user principal) or the org (named principal). `listCredentials` does show unauthenticated credentials — with `isConfigured=false` and the principal type — so agents can tell users which authorization is missing; `describe` and `sendRequest` refuse them.

## Configuration

Guardrails live in the **Named Credentials Configuration** custom metadata type (`Named_Credentials_Configuration__mdt`), one record per Named Credential:

| Field | Purpose |
| --- | --- |
| `Named_Credentials_Developer_Name__c` | DeveloperName of the target Named Credential (Text 255, so it is not limited by the 40-char record name). |
| `Is_Active__c` | Only active records are considered. |
| `Is_Test__c` | Reserved for the package's own test records; leave unchecked for real configurations. |
| `Configuration__c` | The JSON below. |

### `Configuration__c` JSON

```jsonc
{
  "description": "OpenAI Platform REST API",                       // required; shown to agents in describe
  "apiDocsUrl": "https://platform.openai.com/docs/api-reference",  // optional; the reference link shown in describe
  "allowedMethods": ["GET", "POST"],      // optional; DEFAULT ["GET"] — writes and DELETE are opt-in
  "allowedEndpointPatterns": ["/v1/*"],   // optional; DEFAULT ["*"]; "*" matches any characters, including "/"
  "guardrails": ["MyCustomGuardrail"]     // optional; custom ncMcp_Guardrail class names, run after the built-ins
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

## Custom guardrails

Guardrails are a strategy: implement [ncMcp_Guardrail](ncMcp_Guardrail.cls) and add the class name to the `guardrails` list. They run after the built-in checks, in listed order, and receive the whole [ncMcp_GuardedCalloutBuilder](ncMcp_GuardedCalloutBuilder.cls) — its read accessors (`getMethod()`, `getPath()`, `getHeaders()`, `getBody()`, `getConfig()`, ...) expose everything about the request, so a guardrail can enforce rules the declarative config cannot express. Throw `ncMcp_Exception` to block; return normally to allow. Do not execute the builder from inside a guardrail — it throws.

[ncMcp_ExampleGuardrail](ncMcp_ExampleGuardrail.cls) is a copy-ready reference: it blocks any request whose body looks like it contains a credential.

```apex
public with sharing class NoBulkDeleteGuardrail implements ncMcp_Guardrail {
    public void enforce(ncMcp_GuardedCalloutBuilder builder) {
        if (builder.getMethod() == 'DELETE' && builder.getPath().contains('/bulk')) {
            throw new ncMcp_Exception('Bulk delete is not permitted through MCP.');
        }
    }
}
```

**Trust model:** the `guardrails` list runs admin-referenced Apex by name. Configuration records are protected metadata edited by administrators, so this is the same trust boundary as any admin-authored automation — but be deliberate about who can edit these records.

## Org setup

1. Deploy this module.
2. Assign the **Named Credentials MCP User** permission set (grants the three tool classes) to the connecting users, and grant them the relevant Named Credential's external-credential principal access.
3. Create the Named Credential and External Credential as usual; authorize the per-user principal or configure the named principal.
4. Add an active Named Credentials Configuration record (above).
5. Register and activate the MCP server that surfaces `ncMcp_ListCredentialsTool`, `ncMcp_DescribeTool`, and `ncMcp_SendRequestTool`, then connect your MCP client. *(Server registration is handled separately from this module.)*

## Direct Apex usage

[ncMcp_GuardedCalloutBuilder](ncMcp_GuardedCalloutBuilder.cls) mirrors the full CalloutBuilder API, so any Apex callout can opt into guardrail enforcement by swapping the class name:

```apex
HttpResponse response = new ncMcp_GuardedCalloutBuilder('OpenAI_NC')
    .withEndpoint('/v1/models')
    .withHeader('Accept', 'application/json')
    .getHttpResponse();
System.debug(response.getStatusCode() + ' ' + response.getBody());
```

`withSuccessType`/`getTypedResponseBody`, `withRetrier`, `withFile`, and the other CalloutBuilder methods are available unchanged. Differences from a bare CalloutBuilder: query parameters are URL-encoded and appended to the endpoint for **every** HTTP method (not only GET), a `String` passed to `withBody` or `withBlobBody` is sent verbatim (a bare CalloutBuilder would JSON-serialize it a second time), the timeout defaults to 30 s and is clamped to [1 s, 120 s], and `Content-Type` defaults to `application/json` when a body is present. `withBody` JSON-serializes non-String objects.

## Notes and limits

- The MCP `sendRequest` tool sends bodies as UTF-8 text (`Blob.valueOf`); binary request bodies are not supported over MCP (tool inputs are strings anyway). Direct Apex callers can pass binary content via `withBlobBody`/`withFile`, but such bodies are not inspectable by guardrails.
- The authentication check relies on ConnectApi, which reports on unified Named Credentials. Legacy Named Credentials may be reported as unauthenticated.
- ConnectApi is not executable in test context; [ncMcp_AuthenticationGuardrail](ncMcp_AuthenticationGuardrail.cls) exposes a `@TestVisible` status map so tests can simulate authentication states.
