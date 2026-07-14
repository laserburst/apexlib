# apexlib

> Reusable Apex

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![API Version](https://img.shields.io/badge/API-67.0-lightgrey.svg)

## Components

### [CalloutBuilder](force-app/main/calloutBuilder/classes/README.md)

It handles what should have been handled for us long ago. Reduce duplication with CalloutBuilder.

```java
ExampleResponse.DialogToken token = (ExampleResponse.DialogToken)
    new CalloutBuilder('callout:MyNC')
        .withEndpoint('/dialog-tokens')
        .withMethod('POST')
        .withSuccessType(ExampleResponse.DialogToken.class)
        .withErrorType(ExampleResponse.Error.class)
        .getTypedResponseBody();
```

### [ViciousMockery](force-app/main/viciousMockery/classes/README.md)

HTTP mock template. `ViciousMockBase` lets you define mock families using instance initializer blocks; `ViciousMockery` is a drop-in mock for any status code.

```java
ViciousMockery.cast(200);
```

### [ConnectApiAdapter](force-app/main/connectApiAdapter/classes/README.md)

Thin wrapper around the most-used `ConnectApi` methods prepared for use.

### [GuardedCalloutBuilder](force-app/main/guardedCalloutBuilder/classes/README.md)

A guardrail-enforcing decorator that mirrors the CalloutBuilder API. Before any request leaves the org it loads a per-Named-Credential configuration and runs a chain of guardrails — authentication, allowed methods, endpoint patterns, and custom strategies — configured in custom metadata. Nothing is callable until an admin activates a configuration, and the defaults are conservative (GET only). Any Apex callout can opt in by swapping the class name:

```java
HttpResponse response = new GuardedCalloutBuilder('OpenAI_NC')
    .withEndpoint('/v1/models')
    .getHttpResponse();
```

### [Named Credentials MCP](force-app/main/namedCredentialsMcp/README.md)

Three Salesforce-hosted MCP tools that let an AI agent make HTTP callouts through the org's Named Credentials — the token never reaches the AI. `listCredentials` shows which credentials exist and whether each is ready to use; `describe` explains how to call one; `sendRequest` sends a guarded request through [GuardedCalloutBuilder](force-app/main/guardedCalloutBuilder/classes/README.md). The tools are invocable actions, so they also work in Flows and Agentforce.

## Claude Code

A Claude Code skill for CalloutBuilder is included at [.claude/skills/apex-callout-builder/SKILL.md](.claude/skills/apex-callout-builder/SKILL.md). Copy it to your project's `.claude/skills/` directory and Claude will automatically generate, review, and explain CalloutBuilder code — including response DTOs, error handling, test mocks, file uploads, and async callouts.
