/**
 * @description Built-in guardrail: only allows requests to a Named Credential
 * that is authenticated for the running context — a per-user principal the
 * current user has authorized, or a named principal an administrator has
 * configured. It also exposes getStatus() so the listCredentials and describe
 * tools can report whether each credential is ready to use.
 *
 * ConnectApi lookups are not executable in test context, so getStatus() reads
 * from the @TestVisible testStatuses map during tests; seed it to simulate auth
 * states. The evaluation seams below are @TestVisible and accept ConnectApi
 * objects (which can be constructed inside a test) so the logic stays covered.
 * @team Laserburst
 */
public with sharing class ncMcp_AuthenticationGuardrail implements ncMcp_Guardrail {
    /**
     * @description Authentication outcome for one Named Credential. principalType
     * is populated even when not authenticated (from the first principal found),
     * so callers can tell a user which kind of authorization is missing.
     */
    public class Status {
        public Boolean isAuthenticated = false;
        public String principalType;
        public String baseUrl;
    }

    @TestVisible
    private static Map<String, Status> testStatuses = new Map<String, Status>();

    @TestVisible
    private static void stubAuthenticated(String namedCredential, String baseUrl, String principalType) {
        Status status = new Status();
        status.isAuthenticated = true;
        status.baseUrl = baseUrl;
        status.principalType = principalType;
        testStatuses.put(namedCredential, status);
    }

    public void enforce(ncMcp_GuardedCalloutBuilder builder) {
        Status status = getStatus(builder.getNamedCredential());
        if (!status.isAuthenticated) {
            throw new ncMcp_Exception(notAuthenticatedMessage(builder.getNamedCredential()));
        }
    }

    /**
     * @description Shared agent-facing explanation of a failed authentication
     * check; ncMcp_DescribeTool reuses it so the guidance never diverges.
     * @param namedCredential developer name of the Named Credential
     * @return the explanation, without a trailing space
     */
    public static String notAuthenticatedMessage(String namedCredential) {
        return 'Named Credential "' +
            namedCredential +
            '" is not authenticated for the current user. A per-user credential must be authorized by the user, ' +
            'or the named principal must be configured by an administrator.';
    }

    /**
     * @description Resolves whether a Named Credential is usable now and, if so,
     * its principal type and callout base URL.
     * @param namedCredential developer name of the Named Credential
     * @return the resolved Status (never null; isAuthenticated is false when unknown)
     */
    public static Status getStatus(String namedCredential) {
        if (Test.isRunningTest()) {
            return testStatuses.containsKey(namedCredential) ? testStatuses.get(namedCredential) : new Status();
        }
        return evaluate(ConnectApiAdapter.getNamedCredential(namedCredential));
    }

    @TestVisible
    private static Status evaluate(ConnectApi.NamedCredential namedCredential) {
        Status status = new Status();
        if (namedCredential == null) {
            return status;
        }
        status.baseUrl = namedCredential.calloutUrl;
        if (namedCredential.externalCredentials == null) {
            return status;
        }
        for (ConnectApi.ExternalCredential externalCredential : namedCredential.externalCredentials) {
            ConnectApi.ExternalCredential details;
            try {
                details = ConnectApiAdapter.getExternalCredential(externalCredential.developerName);
            } catch (Exception e) {
                continue; // an unreadable External Credential counts as unauthenticated, not as an error
            }
            ConnectApi.ExternalCredentialPrincipal principal = configuredPrincipal(details);
            if (principal != null) {
                status.isAuthenticated = true;
                status.principalType = String.valueOf(principal.principalType);
                return status;
            }
            if (status.principalType == null) {
                status.principalType = firstPrincipalType(details);
            }
        }
        return status;
    }

    @TestVisible
    private static ConnectApi.ExternalCredentialPrincipal configuredPrincipal(ConnectApi.ExternalCredential externalCredential) {
        if (externalCredential == null || externalCredential.principals == null) {
            return null;
        }
        for (ConnectApi.ExternalCredentialPrincipal principal : externalCredential.principals) {
            if (principal.authenticationStatus == ConnectApi.CredentialAuthenticationStatus.Configured) {
                return principal;
            }
        }
        return null;
    }

    @TestVisible
    private static String firstPrincipalType(ConnectApi.ExternalCredential externalCredential) {
        if (externalCredential == null || externalCredential.principals == null || externalCredential.principals.isEmpty()) {
            return null;
        }
        ConnectApi.CredentialPrincipalType principalType = externalCredential.principals[0].principalType;
        return principalType == null ? null : String.valueOf(principalType);
    }
}
