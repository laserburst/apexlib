# Named Credentials MCP

## Purpose

Three tools for a Salesforce hosted MCP server, so an agent can call an external API through a Named Credential. Salesforce adds the credential when the request is sent, so the agent never sees it. Every callout obeys the API's SecureCalloutBuilder policies, and an API is exposed only when a policy allows it.

## Example (illustrative)

Expose an API with one public class:

```Java (Apex)
public class ItemsApiPolicies implements ncMcp_CalloutPolicies {
    public List<CalloutPolicy> getPolicies() {
        return new List<CalloutPolicy>{
            new CalloutPolicy('callout:Api')
                .withAllowedHeaders(new Set<String>{ 'Accept' })
                .withResponseSanitizer(new DropInternalFields()),
            new CalloutPolicy('callout:Api')
                .withMethod('GET')
                .withEndpoint('/items/*')
                .withAllowedQueryParameters(new Set<String>{ 'limit' })
        };
    }
}
```

The agent then sees:

| Tool | Returns |
| --- | --- |
| `listCredentials` | the APIs it can call, each with its name, label and description |
| `describe` | one API's name, label, description and routes: `{"/items/*":["GET"]}` |
| `sendRequest` | the status code, status, headers and body of the response |

## Setup

1. Deploy this module with `calloutBuilder`, `secureCalloutBuilder` and `connectApiAdapter`.
2. Write the API's purpose in its Named Credential's Description. The agent reads it.
3. Assign the **Named Credentials MCP User** permission set. Users also need principal access to each API's External Credential, as usual.
4. Activate the **Named Credentials** MCP server in Setup, under API Catalog, and connect an MCP client.

## Structure

| Class | Role |
| --- | --- |
| [ncMcp_CalloutPolicies](ncMcp_CalloutPolicies.cls) | An API's policies; an org implements it |
| [ncMcp_PolicyFactory](ncMcp_PolicyFactory.cls) | Supplies every policy; one org class that implements it replaces the default |
| [ncMcp_DefaultPolicyFactory](ncMcp_DefaultPolicyFactory.cls) | Collects every `ncMcp_CalloutPolicies` class |
| [ncMcp_PolicyCatalog](ncMcp_PolicyCatalog.cls) | Checks the custom permission, and answers what is exposed |
| [ncMcp_Credential](ncMcp_Credential.cls) | What an agent may know about one Named Credential, from ConnectApi |
| [ncMcp_CredentialList](ncMcp_CredentialList.cls) | Output of `listCredentials` |
| [ncMcp_DescriptionRequest](ncMcp_DescriptionRequest.cls) / [ncMcp_CredentialDescription](ncMcp_CredentialDescription.cls) | Input and output of `describe` |
| [ncMcp_CalloutRequest](ncMcp_CalloutRequest.cls) / [ncMcp_CalloutResponse](ncMcp_CalloutResponse.cls) | Input and output of `sendRequest` |
| [ncMcp_ToolListCredentials](ncMcp_ToolListCredentials.cls), [ncMcp_ToolDescribe](ncMcp_ToolDescribe.cls), [ncMcp_ToolSendRequest](ncMcp_ToolSendRequest.cls) | The invocable actions behind the three tools |
| [ncMcp_ToolException](ncMcp_ToolException.cls) | A missing permission, invalid input or invalid configuration |

The rules for writing the policies are in the [apex-secure-callout-builder](../../../../.claude/skills/apex-secure-callout-builder/SKILL.md) skill.