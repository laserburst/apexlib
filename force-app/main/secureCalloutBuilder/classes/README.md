# SecureCalloutBuilder

## Purpose

An MCP tool or an Agentforce action can pass a callout its path, headers or body. SecureCalloutBuilder makes such a callout obey a list of policies. Nothing is allowed until a policy grants it. A callout that no policy allows is blocked before anything is sent. The response goes through the sanitizers of the applied policies.

## Example (illustrative)

```Java (Apex)
List<CalloutPolicy> itemsApiPolicies = new List<CalloutPolicy>{
    new CalloutPolicy('callout:Api')                       // every callout to the API
        .withAllowedHeaders(new Set<String>{ 'Accept', 'Content-Type' })
        .withResponseSanitizer(new DropInternalFields()),
    new CalloutPolicy('callout:Api')                       // an item and everything below it, any method
        .withEndpoint('/items/{id}/*')
        .withPathParameterPattern('id', '[0-9]+'),
    new CalloutPolicy('callout:Api')
        .withMethod('GET')
        .withEndpoint('/items/*'),
    new CalloutPolicy('callout:Api')                       // /items/{id} is its own route, so GET is named again
        .withMethod('GET')
        .withEndpoint('/items/{id}'),
    new CalloutPolicy('callout:Api')
        .withMethod('PATCH')
        .withEndpoint('/items/{id}')
        .withCondition(new HasPermission('Edit_Items'))
        .withAllowedQueryParameters(new Set<String>{ 'expand' })
};

CalloutBuilder cb = new CalloutBuilder('callout:Api')
    .withMethod('PATCH')
    .withEndpoint('/items/{id}')
    .withPathParameter('id', itemId)
    .withBody(changes);

Map<String, Object> item = new SecureCalloutBuilder(cb)
    .withPolicies(itemsApiPolicies)
    .getResponseBodyMap();
```

## Structure

| Class | Role |
| --- | --- |
| [SecureCalloutBuilder](SecureCalloutBuilder.cls) | Wraps a configured CalloutBuilder, which then obeys the policies even when executed directly |
| [CalloutPolicy](CalloutPolicy.cls) | Which callouts to one API a policy applies to, and what it grants and checks there |
| [CalloutCondition](CalloutCondition.cls) | Abstract class that narrows where a policy applies |
| [CalloutEffectivePolicy](CalloutEffectivePolicy.cls) | What a list of policies gives one callout: its route, grants, checks and sanitizers |
| [CalloutGrants](CalloutGrants.cls) | What a callout may send; grants from several policies add up |
| [CalloutRequestSnapshot](CalloutRequestSnapshot.cls) | What the builder sends, read once, and the fixed rules no policy can lift |
| [CalloutEndpointPattern](CalloutEndpointPattern.cls) | An endpoint pattern such as `/items/{id}/*`, ranked by how specific it is |
| [CalloutPolicyException](CalloutPolicyException.cls) | A block before anything is sent, with the [CalloutPolicyRule](CalloutPolicyRule.cls) that caused it |

The rules, the pattern syntax and the guidance are in the [apex-secure-callout-builder](../../../../.claude/skills/apex-secure-callout-builder/SKILL.md) skill.