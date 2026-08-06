# Named Credentials MCP

Exposes three Salesforce-hosted MCP tools so an AI agent can make HTTP callouts through the org's Named Credentials — **without ever seeing a token**. Salesforce injects authentication; every request passes through configurable guardrails. For the high-level architecture, see [How It Works](../README.md).

Because the tools are Apex invocable actions, they are equally usable from Flows and Agentforce, and the callout core is callable directly from Apex.

## Tools

| Tool | Class | Purpose |
| --- | --- | --- |
| `listCredentials` | [ncMcp_ListCredentialsTool](ncMcp_ListCredentialsTool.cls) | Lists the exposed credentials and whether each is ready to use (name, `isConfigured`, base URL, principal type). Unauthenticated credentials are included, so an agent can tell the user what is missing. |
| `describe` | [ncMcp_DescribeTool](ncMcp_DescribeTool.cls) | Returns how to use **one** credential: purpose, docs URL, base URL, allowed methods and endpoint patterns. Errors when the credential is unknown or not authenticated. |
| `sendRequest` | [ncMcp_SendRequestTool](ncMcp_SendRequestTool.cls) | Sends a guarded HTTP request through a Named Credential and returns the response. |

All three are thin invocable wrappers. The callout path and every guardrail live in the separate, MCP-independent [GuardedCalloutBuilder](../../guardedCalloutBuilder/classes/README.md) module — a [CalloutBuilder](../../calloutBuilder/classes/CalloutBuilder.cls) subclass that enforces the guardrail chain. That module also owns the **Named Credentials Configuration** custom metadata type, the guardrail interface, and the custom-guardrail how-to.

## How it works

1. `listCredentials` returns every credential with an active configuration and its authentication status for the running user.
2. `describe` returns the usage contract for one credential: its purpose, docs URL, allowed methods, and endpoint patterns.
3. `sendRequest` builds a `GuardedCalloutBuilder`. Before the request leaves the org, it loads the credential's configuration and runs the guardrail chain:
   authentication → allowed method → allowed endpoint → any custom guardrails.
4. On success the response (status code, status text, body, headers) is returned. On an HTTP status ≥ 400 the callout raises `CalloutBuilder.CalloutBuilderException` (its message carries the response body); on a guardrail violation it raises `CalloutGuardrailException`, and on bad input the tool's own inner exception (`ncMcp_SendRequestTool.ncMcp_SendRequestToolException`).

Nothing is usable by default. An API can be called only when an admin adds an active configuration record for it **and** the Named Credential is authenticated for the running user (per-user principal) or the org (named principal). `listCredentials` does show unauthenticated credentials — with `isConfigured=false` and the principal type — so agents can tell users which authorization is missing; `describe` and `sendRequest` refuse them.

## Configuration

The guardrail configuration (the `Named_Credentials_Configuration__mdt` record format, the `Configuration__c` JSON schema, and how to write a custom guardrail) lives with the engine in the [GuardedCalloutBuilder module reference](../../guardedCalloutBuilder/classes/README.md).

## Org setup

1. Deploy this module and the [guardedCalloutBuilder](../../guardedCalloutBuilder/classes/README.md) module.
2. Assign the **Named Credentials MCP User** permission set (grants the three tool classes) to the connecting users, and grant them the relevant Named Credential's external-credential principal access.
3. Create the Named Credential and External Credential as usual; authorize the per-user principal or configure the named principal.
4. Add an active Named Credentials Configuration record (see the module reference above).
5. Register and activate the MCP server that surfaces `ncMcp_ListCredentialsTool`, `ncMcp_DescribeTool`, and `ncMcp_SendRequestTool`, then connect your MCP client. *(Server registration is handled separately from this module.)*

## Notes and limits

- The MCP `sendRequest` tool sends bodies as UTF-8 text (`Blob.valueOf`); binary request bodies are not supported over MCP (tool inputs are strings anyway). Direct Apex callers can pass binary content via `withBlobBody`/`withFile`, but such bodies are not inspectable by guardrails.
- The authentication check relies on ConnectApi, which reports on unified Named Credentials. Legacy Named Credentials may be reported as unauthenticated.
