@IsTest
private class ncMcp_DefaultPolicyFactory_Test {
    private static final String TEST_CLASS = 'ncMcp_DefaultPolicyFactory_Test';

    @IsTest
    static void testFactoryChoice() {
        Map<String, List<String>> classNamesByCase =
            new Map<String, List<String>>{
                'none' => new List<String>(),
                'only the default' => new List<String>{ 'ncMcp_DefaultPolicyFactory' },
                'one replacement' => new List<String>{ 'ncMcp_DefaultPolicyFactory', TEST_CLASS + '.OrgFactory' },
                'a class that does not load' => new List<String>{ 'ncMcp_NoSuchFactory' },
                'two replacements' => new List<String>{ TEST_CLASS + '.OrgFactory', TEST_CLASS + '.OtherFactory' }
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'none' => 'default',
                'only the default' => 'default',
                'one replacement' => 'replacement',
                'a class that does not load' => 'Class ncMcp_NoSuchFactory could not be loaded',
                'two replacements' => 'More than one class implements ncMcp_PolicyFactory'
            };

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : classNamesByCase.keySet()) {
            outcomeByCase.put(testCase, toOutcome(classNamesByCase.get(testCase)));
        }
        Test.stopTest();

        Assert.areEqual(expectedByCase, outcomeByCase, 'One replacement should win, and anything unclear should throw');
    }

    @IsTest
    static void testToPolicies() {
        List<ApexTypeImplementor> implementors =
            toImplementors(new List<String>{ TEST_CLASS + '.ItemsPolicies', TEST_CLASS + '.OrdersPolicies' });

        Test.startTest();
        List<CalloutPolicy> policies = new ncMcp_DefaultPolicyFactory().toPolicies(implementors);
        Test.stopTest();

        List<String> scopes = new List<String>();
        for (CalloutPolicy policy : policies) {
            scopes.add(policy.getNcOrBaseUrl());
        }
        Assert.areEqual(
            new List<String>{ 'callout:Items', 'callout:Items', 'callout:Orders' },
            scopes,
            'Every policy of each class should be collected'
        );
    }

    private static String toOutcome(List<String> classNames) {
        try {
            ncMcp_PolicyFactory factory = ncMcp_DefaultPolicyFactory.toFactory(toImplementors(classNames));
            if (factory instanceof OrgFactory) {
                return 'replacement';
            }
            return 'default';
        } catch (ncMcp_ToolException e) {
            return e.getMessage();
        }
    }

    // ApexTypeImplementor fields aren't writable
    private static List<ApexTypeImplementor> toImplementors(List<String> classNames) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (String className : classNames) {
            rows.add(new Map<String, String>{ 'ClassName' => className });
        }
        return (List<ApexTypeImplementor>) JSON.deserialize(JSON.serialize(rows), List<ApexTypeImplementor>.class);
    }

    public class OrgFactory implements ncMcp_PolicyFactory {
        public List<CalloutPolicy> getPolicies() {
            return new List<CalloutPolicy>();
        }
    }

    public class OtherFactory implements ncMcp_PolicyFactory {
        public List<CalloutPolicy> getPolicies() {
            return new List<CalloutPolicy>();
        }
    }

    public class ItemsPolicies implements ncMcp_CalloutPolicies {
        public List<CalloutPolicy> getPolicies() {
            return new List<CalloutPolicy>{
                new CalloutPolicy('callout:Items').withMethod('GET'),
                new CalloutPolicy('callout:Items').withAllowedHeaders(new Set<String>{ 'Accept' })
            };
        }
    }

    public class OrdersPolicies implements ncMcp_CalloutPolicies {
        public List<CalloutPolicy> getPolicies() {
            return new List<CalloutPolicy>{ new CalloutPolicy('callout:Orders').withMethod('GET') };
        }
    }
}