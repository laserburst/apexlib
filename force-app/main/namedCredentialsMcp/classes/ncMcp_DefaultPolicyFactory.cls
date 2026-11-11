/**
 * @description ncMcp_DefaultPolicyFactory supplies the policies of every ncMcp_CalloutPolicies class, in class name
 * order, so sanitizers from different classes run in that order. Extend it to add policies.
 * @team Laserburst
 */
public with sharing virtual class ncMcp_DefaultPolicyFactory implements ncMcp_PolicyFactory {
    /**
     * @description forOrg returns the one other public class that implements ncMcp_PolicyFactory, or the default
     * when there is none; it throws when there are two or more
     */
    public static ncMcp_PolicyFactory forOrg() {
        return toFactory(findImplementors(ncMcp_PolicyFactory.class));
    }

    public virtual List<CalloutPolicy> getPolicies() {
        return this.toPolicies(findImplementors(ncMcp_CalloutPolicies.class));
    }

    @TestVisible
    private static ncMcp_PolicyFactory toFactory(List<ApexTypeImplementor> implementors) {
        List<ApexTypeImplementor> replacements = new List<ApexTypeImplementor>();
        for (ApexTypeImplementor implementor : implementors) {
            if (implementor.ClassName != ncMcp_DefaultPolicyFactory.class.getName()) {
                replacements.add(implementor);
            }
        }
        if (replacements.isEmpty()) {
            return new ncMcp_DefaultPolicyFactory();
        }
        if (replacements.size() > 1) {
            throw new ncMcp_ToolException('More than one class implements ncMcp_PolicyFactory');
        }
        return (ncMcp_PolicyFactory) toInstance(replacements[0]);
    }

    @TestVisible
    private List<CalloutPolicy> toPolicies(List<ApexTypeImplementor> implementors) {
        List<CalloutPolicy> policies = new List<CalloutPolicy>();
        for (ApexTypeImplementor implementor : implementors) {
            policies.addAll(((ncMcp_CalloutPolicies) toInstance(implementor)).getPolicies());
        }
        return policies;
    }

    // system mode: an MCP user usually can't read setup objects
    private static List<ApexTypeImplementor> findImplementors(System.Type interfaceType) {
        String interfaceName = interfaceType.getName();
        return [
            SELECT ClassNamespacePrefix, ClassName
            FROM ApexTypeImplementor
            WHERE InterfaceName = :interfaceName AND InterfaceNamespacePrefix = '' AND IsConcrete = TRUE
            WITH SYSTEM_MODE
            ORDER BY ClassNamespacePrefix, ClassName
        ];
    }

    // fails closed: skipping a class could drop the checks that another class's routes rely on
    private static Object toInstance(ApexTypeImplementor implementor) {
        System.Type implementorType = Type.forName(implementor.ClassNamespacePrefix, implementor.ClassName);
        if (implementorType == null) {
            throw new ncMcp_ToolException('Class ' + implementor.ClassName + ' could not be loaded');
        }
        return implementorType.newInstance();
    }
}