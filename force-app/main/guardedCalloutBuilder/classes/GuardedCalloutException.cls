/**
* @description Thrown for guarded-callout configuration problems, invalid input,
* and guardrail violations. HTTP responses with a status >= 400 raise
* CalloutBuilder.CalloutBuilderException instead.
* @team Laserburst
*/
public class GuardedCalloutException extends Exception {
}