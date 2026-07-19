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

    // URL the user visits to authorize a credential (OAuth flow)
    String authUrl = ConnectApiAdapter.getCredentialAuthenticationUrl(
        'externalCredential',
        'principalName',
        ConnectApi.CredentialPrincipalType.PERUSERPRINCIPAL
    );

    // Single-parameter overloads: the principal (and the protocol for refreshToken)
    // are resolved from the external credential automatically
    ConnectApiAdapter.refreshToken('externalCredential');
    Boolean isConfigured = ConnectApiAdapter.isCredentialConfigured('externalCredential');
    authUrl = ConnectApiAdapter.getCredentialAuthenticationUrl('externalCredential');
```

The single-parameter overloads require the external credential to have exactly one principal; otherwise they throw `ConnectApiAdapter.ConnectApiAdapterException` — use the full-parameter methods in that case.
