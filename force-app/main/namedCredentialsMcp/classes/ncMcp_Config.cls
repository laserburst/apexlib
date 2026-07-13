/**
 * @description Parsed guardrail configuration for one Named Credential, loaded
 * from the Named_Credentials_Configuration__mdt custom metadata type. The public
 * fields map directly to the Configuration__c JSON; missing values are resolved
 * to safe defaults by normalize().
 * @team Laserburst
 */
public with sharing class ncMcp_Config {
    // Populated by JSON.deserialize of Configuration__c
    public String description;
    public String apiDocsUrl;
    public List<String> allowedMethods;
    public List<String> allowedEndpointPatterns;
    public List<String> guardrails;

    // Set from the record, not the JSON
    public String namedCredential;

    /**
     * @description Loads all active configurations in the current context,
     * keyed by Named Credential developer name. Records whose JSON cannot be
     * parsed are skipped and logged, so one bad record cannot break discovery.
     * @return map of Named Credential developer name to its resolved config
     */
    public static Map<String, ncMcp_Config> getActive() {
        Map<String, ncMcp_Config> configs = new Map<String, ncMcp_Config>();
        for (Named_Credentials_Configuration__mdt record : query(null)) {
            try {
                ncMcp_Config config = parse(record);
                configs.put(config.namedCredential, config);
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.DEBUG,
                    'ncMcp: skipping malformed configuration for "' +
                        record.Named_Credentials_Developer_Name__c +
                        '": ' +
                        e.getMessage()
                );
            }
        }
        return configs;
    }

    /**
     * @description Loads the active configuration for one Named Credential.
     * @param namedCredential developer name of the Named Credential
     * @return the resolved config
     * @throws ncMcp_Exception when no active config exists or its JSON is invalid
     */
    public static ncMcp_Config forName(String namedCredential) {
        for (Named_Credentials_Configuration__mdt record : query(namedCredential)) {
            try {
                return parse(record);
            } catch (Exception e) {
                throw new ncMcp_Exception(
                    'Configuration for Named Credential "' +
                        namedCredential +
                        '" is not valid JSON. Contact an administrator.'
                );
            }
        }
        throw new ncMcp_Exception(
            'No active configuration found for Named Credential "' +
                namedCredential +
                '". Call the listCredentials tool to list available credentials.'
        );
    }

    private static List<Named_Credentials_Configuration__mdt> query(String namedCredential) {
        if (namedCredential == null) {
            return [
                SELECT Named_Credentials_Developer_Name__c, Configuration__c
                FROM Named_Credentials_Configuration__mdt
                WHERE Is_Active__c = TRUE AND Is_Test__c = :Test.isRunningTest()
            ];
        }
        return [
            SELECT Named_Credentials_Developer_Name__c, Configuration__c
            FROM Named_Credentials_Configuration__mdt
            WHERE
                Is_Active__c = TRUE
                AND Is_Test__c = :Test.isRunningTest()
                AND Named_Credentials_Developer_Name__c = :namedCredential
            LIMIT 1
        ];
    }

    private static ncMcp_Config parse(Named_Credentials_Configuration__mdt record) {
        ncMcp_Config config = String.isBlank(record.Configuration__c)
            ? new ncMcp_Config()
            : (ncMcp_Config) JSON.deserialize(record.Configuration__c, ncMcp_Config.class);
        config.namedCredential = record.Named_Credentials_Developer_Name__c;
        config.normalize();
        return config;
    }

    private void normalize() {
        if (this.allowedMethods == null || this.allowedMethods.isEmpty()) {
            this.allowedMethods = new List<String>{ 'GET' };
        } else {
            List<String> upper = new List<String>();
            for (String method : this.allowedMethods) {
                if (String.isNotBlank(method)) {
                    upper.add(method.trim().toUpperCase());
                }
            }
            this.allowedMethods = upper;
        }
        if (this.allowedEndpointPatterns == null || this.allowedEndpointPatterns.isEmpty()) {
            this.allowedEndpointPatterns = new List<String>{ '*' };
        }
        if (this.guardrails == null) {
            this.guardrails = new List<String>();
        }
    }
}
