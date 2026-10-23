/**
 * Subscriber for Integration_Error__e: turns each event into an Integration_Log__c record.
 * Platform event triggers run as the Automated Process user, so this class runs in system
 * context; it only copies the event fields, which never contain PHI or full account numbers.
 */
public inherited sharing class IntegrationErrorLogger {
    // Runs as the Automated Process user from a platform event trigger; writing the log in
    // system mode is intentional so failures are always recorded.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void logEvents(List<Integration_Error__e> events) {
        List<Integration_Log__c> logs = new List<Integration_Log__c>();
        for (Integration_Error__e event : events) {
            logs.add(
                new Integration_Log__c(
                    Operation__c = event.Operation__c,
                    Status_Code__c = event.Status_Code__c,
                    Message__c = event.Message__c,
                    Correlation_Id__c = event.Correlation_Id__c,
                    Occurred_At__c = event.CreatedDate
                )
            );
        }
        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}
