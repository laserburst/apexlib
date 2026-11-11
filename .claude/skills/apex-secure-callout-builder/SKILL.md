---
name: apex-secure-callout-builder
description: >-
  Writes and reviews CalloutPolicy lists and SecureCalloutBuilder code, which keep Apex callouts to an API within
  what its policies allow. Use it whenever a callout carries values the Apex code didn't choose: a path, header,
  query parameter or body from an MCP tool, an Agentforce action, a Flow or a user. Trigger on "SecureCalloutBuilder",
  "CalloutPolicy", "withPolicy", "withPolicies", "CalloutPolicyException", "CalloutPolicyRule", "CalloutCondition",
  "allow-list an API", "restrict which endpoints", "block callouts", "ncMcp_CalloutPolicies", "ncMcp_PolicyFactory",
  "Named Credentials MCP", or a review of an agent tool that calls out.
  It builds on apex-callout-builder, which covers the CalloutBuilder itself.
---

# SecureCalloutBuilder

Wrap a fully configured CalloutBuilder and give it the API's policies:

```apex
Map<String, Object> item = new SecureCalloutBuilder(cb)
    .withPolicies(itemsApiPolicies)
    .getResponseBodyMap();
```

The wrapper attaches its enforcer to the builder itself, so `cb.getHttpResponse()` is just as secure, and so is a queued builder.

---

## How a callout is decided

1. **Path rule.** The path after the base URL is decoded once, with `+` kept. It is blocked (`PATH`) when:
   - it can't be decoded, or isn't UTF-8;
   - a segment is empty, other than a trailing `/`;
   - a segment is `.` or `..`;
   - a decoded segment contains `/`, `\`, `;`, `%` or a control character.

   So an encoded `/` or `%` in a path parameter value is blocked: matrix parameters, GitLab-style `group%2Fproject` and S3-style keys can't go through. A server could split such a value into segments or decode it again, and then serve a path that no policy checked.
2. **Applicable.** A policy applies when its base URL equals the callout's (a trailing `/` ignored), it names the method or names none, its endpoint matches the decoded path or it has none, and every condition is met.
3. **Route.** Only a policy that names a method can allow. Among those whose base URL and endpoint match, the most specific endpoint wins, whatever the method and conditions. Equally specific endpoints form one route.
   - No route: `NO_ROUTE`.
   - A policy on the route must name the method and meet its conditions, or the callout is blocked (`METHOD`). It never falls back to a broader route, as OpenAPI answers 405.
4. **Grants add up, like permission sets.** They come from every applicable policy without a method, plus the route's policies that allow the callout. A losing route grants nothing. Nothing is allowed until it is granted:
   - headers: `withAllowedHeaders()`, or one exact value with `withHeaderFormula()` (`HEADER`);
   - query parameters, in the URL and sent as the body: `withAllowedQueryParameters()` (`QUERY_PARAMETER`);
   - a Blob body: `withBlobBodies()` (`BLOB_BODY`);
   - a response header whose name contains `cookie`, `token`, `secret`, `session`, `password`, `credential`, `authorization`, `api-key` or `apikey`: `withAllowedResponseHeaders()`. Without the grant, the header comes back blank in the `HttpResponse`, also for an error response under `withBypassResponseValidation(true)`.
5. **Checks all run, like restriction rules.** Every applicable policy's guardrails and path parameter patterns run, losing routes included (`PATH_PARAMETER` when a whole `{name}` value doesn't match). Every applicable policy's sanitizers see the response.
6. **Fixed rules.** No grant lifts these:
   - a header set in two cases (`HEADER`);
   - `;` in the URL query, or a name in it twice, compared without case (`QUERY_PARAMETER`);
   - `{!` in the body, or in a header whose exact value isn't granted with `withHeaderFormula()` (`FORMULA`);
   - `_method`, `_HttpMethod` or `X-HTTP-Method-Override` as a field in a form body, or in query parameters sent as the body (`METHOD_OVERRIDE`).
7. **Error bodies** are withheld unless a granting policy calls `withErrorBodies()` and every applicable policy with sanitizers does too, also under `withBypassResponseValidation(true)`. A withheld body comes back blank, and the `CalloutBuilderException` keeps its `code` with the message `Withheld by policy`.

Each policy's guardrails and path parameter patterns run first, then the fixed rules, then the grants.

## Endpoint patterns

The syntax of `withEndpoint()`, plus a trailing `/*`:

| Pattern | Matches | Doesn't match |
|---|---|---|
| `/items/{id}` | `/items/5`, `/ITEMS/a b/` | `/items`, `/items/5/notes` |
| `/items/*` | `/items`, `/items/5/notes` | `/items-admin` |
| `/items/{id}/*` | `/items/5`, `/items/5/notes` | `/items` |
| `/` | the root | `/items` |

- Literals are compared without case, and a trailing `/` is ignored on both sides.
- `{name}` must be a whole segment, and matches any non-empty value. Check the value with `withPathParameterPattern(name, regex)`, which must match the whole value.
- Specificity, compared segment by segment from the left: a literal beats `{name}`, `{name}` beats `/*`, and a pattern that ends beats one that goes on with `/*`. A policy without an endpoint ranks last.
- These throw `CalloutBuilderException`: no leading `/`; `?`, `#`, or a `*` other than a trailing `/*`; `{name}.json` or `{a}{b}`; a name used twice; a literal the path rule would block.

## Case rules

| What | Compared |
|---|---|
| Method | in upper case |
| Base URL | with `equals()`, after a trailing `/` is removed |
| Path literals | without case |
| Header names | without case |
| Query parameter names | exactly, so `expand` doesn't grant `Expand` |

## What each exception means

| Exception | Meaning |
|---|---|
| `CalloutPolicyException` | The policies blocked the callout, and nothing was sent. Read `rule`. The message names the method, the path and the offending name, never a value, so an agent may read it. It extends `CalloutGuardrailException`. |
| `CalloutBuilderException` with a `code` | The response was an error. The message is `Withheld by policy` when the body was withheld. |
| `CalloutResponseSanitizerException` | A sanitizer blocked the response. The request was sent, so a write may have happened. |
| `CalloutBuilderException` without a `code`, at setup | A blank scope or one with `?`, `#` or whitespace, an invalid endpoint pattern, a second `withEndpoint()`, or a path parameter pattern for a `{name}` the endpoint lacks. |

---

## Guidance

### Build

- Configure the CalloutBuilder fully before wrapping it. A guardrail added afterwards runs after the policies, when the request has already passed them.
- Name every method at the most specific path that serves it. A more specific route doesn't inherit a broader route's methods or grants, while checks still run from every applicable policy:

  ```apex
  new CalloutPolicy('callout:Api').withMethod('GET').withEndpoint('/items/*'),
  new CalloutPolicy('callout:Api').withMethod('GET').withEndpoint('/items/{id}'), // GET named again
  new CalloutPolicy('callout:Api').withMethod('PATCH').withEndpoint('/items/{id}')
  ```
- Use `/{name}/*` for a check that must cover an item and everything below it.
- Put what every callout to the API needs, such as `Accept`, `Content-Type` and the redacting sanitizers, in one policy without a method.

### Grants and checks

- Grant every header the CalloutBuilder sets, `Accept` and `Content-Type` included. The Content-Type CB adds by default isn't checked.
- Grant `X-HTTP-Method-Override`, `X-Original-URL`, `X-Forwarded-*`, `Host` or `Range` only when the API needs them. Each can get around a method, path or sanitizer rule.
- Check bodies in a guardrail with `getBodyAsString()`, which also covers query parameters sent as the body.
- Write path parameter patterns for the whole value: `withPathParameterPattern('id', '[0-9]+')`.

### Conditions

- Extend `CalloutCondition` and override `isMet()`. It must not execute or change the builder.
- On a policy without a method, a condition that isn't met skips that policy's checks for that user. Put the condition on the exception ("everyone except admins gets the redactor"), so the check is what applies by default.
- Whether a user may call the API at all is already Salesforce's job, through permission set access to the External Credential principal. Conditions add the per-method and per-endpoint layer.
- A condition sees the user the transaction runs as. In a Queueable that's the user who enqueued it, and an Agentforce service agent runs as its agent user, not the customer. A check on the customer has to read the identity from the request context.

### Errors and retries

- Catch `CalloutPolicyException` and read `rule`, for audit or for a reply to an agent.
- Don't retry after a `CalloutResponseSanitizerException` on a write: the write happened.
- A retrier must only decide, as `CalloutRetrier` requires. One that changes the builder and executes it again can pair a resent request with another request's sanitizers.

### Responses

- Pin `withResponseParser(new CalloutJsonParser())` on the CalloutBuilder when Map sanitizers assume JSON. Otherwise `.xml`, `?format=xml` or an `Accept` header can switch the response to XML, whose Map has a different shape.
- A queued builder calls `getHttpResponse()`, so only `sanitize(HttpResponse)` runs. A policy used with queued builders needs that overload.

### Tests

- Unit-test a policy list without callouts: `new CalloutEffectivePolicy(policies, cb).enforce(cb)` throws the same `CalloutPolicyException` a callout would.

---

## Exposing an API to Named Credentials MCP

The `namedCredentialsMcp` module's tools apply every policy that the org's `ncMcp_CalloutPolicies` classes return:

```apex
public class ItemsApiPolicies implements ncMcp_CalloutPolicies {
    public List<CalloutPolicy> getPolicies() {
        return new List<CalloutPolicy>{
            new CalloutPolicy('callout:Api').withMethod('GET').withEndpoint('/items/*')
        };
    }
}
```

- A Named Credential is exposed when a policy scoped `callout:<name>` names a method. Write the scope without a path: `callout:Api/v2` throws, because the tools never call it.
- Make the class public, with a public no-argument constructor. Private classes aren't found.
- Declare test classes private. An implementation inside a public test class is found and applied in production too.
- Keep an API's policies without a method in the same class as its routes, so one can't be left behind.
- Sanitizers from different classes run in class name order.
- One class that fails to load makes every tool throw, so a missing check can't go unnoticed.
- To produce the policies another way, write one public class that implements `ncMcp_PolicyFactory`. It replaces `ncMcp_DefaultPolicyFactory`, and it may extend it and call `super.getPolicies()`. A second one makes every tool throw.
- Write the API's purpose in the Named Credential's Description, which the agent reads.

### Responses

- The tools read the raw response, so only `sanitize(HttpResponse)` and `sanitizeError()` run. Override `sanitize(HttpResponse)`: a sanitizer with only the Map overload blocks every response.
- `sanitize(HttpResponse)` also gets error responses, whose body is blank when withheld.
- The agent gets every response header, except the credential headers that Secure CB blanks unless a policy calls `withAllowedResponseHeaders()`.
- To hide another header, blank it with `setHeader(key, '')`, using the key exactly as `getHeaderKeys()` returns it:

  ```apex
  for (String key : response.getHeaderKeys()) {
      if (key != null && key.equalsIgnoreCase('X-Internal-Id')) {
          response.setHeader(key, '');
      }
  }
  ```
- An endpoint that echoes the request, such as a debug or echo route, returns the credential the Named Credential added. Don't allow it, or sanitize its body.
