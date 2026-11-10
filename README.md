# apexlib

> Reusable Apex

![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
![API Version](https://img.shields.io/badge/API-68.0-lightgrey.svg)

## Components

### [CalloutBuilder](force-app/main/calloutBuilder/classes/README.md)

It handles what should have been handled for us long ago. Reduce duplication with CalloutBuilder.

XML support: send Apex objects as XML and read XML responses into Apex types.

```java
ExampleResponse.DialogToken token = (ExampleResponse.DialogToken)
    new CalloutBuilder('callout:MyNC')
        .withEndpoint('/dialog-tokens')
        .withMethod('POST')
        .withSuccessType(ExampleResponse.DialogToken.class)
        .withErrorType(ExampleResponse.Error.class)
        .getTypedResponseBody();
```

### [SecureCalloutBuilder](force-app/main/secureCalloutBuilder/classes/README.md)

Keeps callouts built from untrusted input, such as an agent's tool call, within the API's policies.

```java
List<CalloutPolicy> itemsApiPolicies = new List<CalloutPolicy>{
    new CalloutPolicy('callout:Api').withMethod('GET').withEndpoint('/items/{id}')
};

CalloutBuilder cb = new CalloutBuilder('callout:Api')
    .withMethod(toolInput.method) // the agent asks for DELETE
    .withEndpoint('/items/{id}')
    .withPathParameter('id', toolInput.itemId);

try {
    Map<String, Object> item = new SecureCalloutBuilder(cb).withPolicies(itemsApiPolicies).getResponseBodyMap();
} catch (CalloutPolicyException e) {
    // nothing was sent; e.rule is METHOD, e.getMessage() is 'DELETE /items/5: method is not allowed on this path'
}
```

### [ViciousMockery](force-app/main/viciousMockery/classes/README.md)

HTTP mock template. `ViciousMockBase` lets you define mock families using instance initializer blocks; `ViciousMockery` is a drop-in mock for any status code.

```java
ViciousMockery.cast(200);
```

### [ConnectApiAdapter](force-app/main/connectApiAdapter/classes/README.md)

Thin wrapper around the most-used `ConnectApi` methods prepared for use.

```java
// requires the external credential to have exactly one principal
ConnectApiAdapter.refreshToken('MyExternalCredential');
```

## Claude Code

A Claude Code skill for CalloutBuilder is included at [.claude/skills/apex-callout-builder/SKILL.md](.claude/skills/apex-callout-builder/SKILL.md). Copy it to your project's `.claude/skills/` directory and Claude will automatically generate, review, and explain CalloutBuilder code — including response DTOs, error handling, test mocks, file uploads, and async callouts.

A second skill, [.claude/skills/apex-secure-callout-builder/SKILL.md](.claude/skills/apex-secure-callout-builder/SKILL.md), writes and reviews the policies for SecureCalloutBuilder.
