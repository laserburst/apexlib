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

## Claude Code

A Claude Code skill for CalloutBuilder is included at [.claude/skills/apex-callout-builder/SKILL.md](.claude/skills/apex-callout-builder/SKILL.md). Copy it to your project's `.claude/skills/` directory and Claude will automatically generate, review, and explain CalloutBuilder code — including response DTOs, error handling, test mocks, file uploads, and async callouts.
