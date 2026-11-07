/**
* @description Queueable context to run multiple CalloutBuilder instances,
* for example from trigger.
* @team Laserburst
*/
public with sharing virtual class CalloutBuilderQueueable implements Queueable, Database.AllowsCallouts {
    private CalloutCollection callouts;
    private Datetime beginning;

    private static final Long MS_BEFORE_ENQUEUE = 110000;
    private static final Integer MAX_CALLS_BUFFER = 5;

    public CalloutBuilderQueueable(CalloutCollection callouts) {
        this.callouts = callouts;
    }

    public static String enqueue(CalloutCollection callouts) {
        return System.enqueueJob(new CalloutBuilderQueueable(callouts));
    }

    public void execute(QueueableContext context) {
        this.beginning = System.now();
        this.callouts.prepare();
        while (!callouts.isEmpty()) {
            if (this.shouldEnqueueNewJob()) {
                this.enqueueRemaining();
                return;
            } else {
                this.callouts.executeNext();
            }
        }
    }

    protected virtual Boolean shouldEnqueueNewJob() {
        return this.isAlmostTwoMinutesFromBeginning() || this.isApproachingCalloutLimit();
    }

    private String enqueueRemaining() {
        return System.enqueueJob(new CalloutBuilderQueueable(this.callouts));
    }

    protected Boolean isAlmostTwoMinutesFromBeginning() {
        if (this.beginning == null) {
            return false;
        }
        Long elapsed = System.now().getTime() - this.beginning.getTime();
        return elapsed >= MS_BEFORE_ENQUEUE;
    }

    protected Boolean isApproachingCalloutLimit() {
        return Limits.getCallouts() >= (Limits.getLimitCallouts() - MAX_CALLS_BUFFER);
    }
}