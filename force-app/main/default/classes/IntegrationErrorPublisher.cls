/**
 * Publishes Integration_Error__e. The event is configured to publish immediately,
 * so it is delivered even if the calling transaction later rolls back.
 */
public with sharing class IntegrationErrorPublisher {
    @TestVisible
    private static List<Integration_Error__e> published = new List<Integration_Error__e>();

    public static void publish(String operation, Integer statusCode, String message, String correlationId) {
        Integration_Error__e event = new Integration_Error__e(
            Operation__c = operation,
            Status_Code__c = statusCode,
            Message__c = message == null ? null : message.left(255),
            Correlation_Id__c = correlationId
        );
        published.add(event);
        Database.SaveResult result = EventBus.publish(event);
        if (!result.isSuccess()) {
            System.debug(LoggingLevel.ERROR, 'Integration_Error__e not published: ' + result.getErrors()[0].getMessage());
        }
    }
}
