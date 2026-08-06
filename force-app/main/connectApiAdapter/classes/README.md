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

    Boolean isConfigured = ConnectApiAdapter.isCredentialConfigured(
        'externalCredential',
        'principalName',
        ConnectApi.CredentialPrincipalType.PERUSERPRINCIPAL
    );

    // Single-parameter overloads require exactly one principal on the external credential
    ConnectApiAdapter.refreshToken('externalCredential');
    isConfigured = ConnectApiAdapter.isCredentialConfigured('externalCredential');
    authUrl = ConnectApiAdapter.getCredentialAuthenticationUrl('externalCredential');
```

The single-parameter overloads throw `ConnectApiAdapter.ConnectApiAdapterException` when the external credential cannot be retrieved, has other than exactly one principal, or — for `refreshToken()` — exposes no authentication protocol. Use the full-parameter methods in those cases.
