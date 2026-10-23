trigger IntegrationErrorTrigger on Integration_Error__e(after insert) {
    IntegrationErrorLogger.logEvents(Trigger.new);
}
