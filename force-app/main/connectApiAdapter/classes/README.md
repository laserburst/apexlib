# ConnectApiAdapter

## Purpose

Simplifying work with ConnectApi namespace.

## Structure

1. [ConnectApiAdapter](ConnectApiAdapter.cls) - class with a subset of prepared, the most frequently used methods from the ConnectApi namespace.

## Example (illustrative)

```Java (Apex)
    ConnectApiAdapter.refreshToken(
        'externalCredential',
        'principalName',
        ConnectApi.CredentialPrincipalType.PERUSERPRINCIPAL,
        ConnectApi.CredentialAuthenticationProtocol.OAUTH
    );
```
