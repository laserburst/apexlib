/**
* @description Output type of the describe MCP tool. api is a JSON object
* string (rather than a nested Apex type) because a documented JSON string
* renders reliably in an MCP output schema. Its shape is the Api class, below.
* @team Laserburst
*/
global with sharing class ncMcp_DescribeResult {
    @InvocableVariable(
        description='JSON object string: {"name":"<use as sendRequest.namedCredential>","description":"what the API does","apiDocsUrl":"API reference documentation, may be null","baseUrl":"resolved callout base URL","allowedMethods":["GET",...],"allowedEndpointPatterns":["/v1/*",...]}.'
    )
    global String api;

    global ncMcp_DescribeResult() {
    }

    global ncMcp_DescribeResult(String api) {
        this.api = api;
    }

    /**
    * @description The described API, as serialized into api.
    */
    public class Api {
        public String name;
        public String description;
        public String apiDocsUrl;
        public String baseUrl;
        public List<String> allowedMethods;
        public List<String> allowedEndpointPatterns;
    }
}