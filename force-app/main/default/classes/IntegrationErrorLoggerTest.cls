@IsTest
private class IntegrationErrorLoggerTest {
    @IsTest
    static void publishedErrorBecomesLogRecord() {
        Test.startTest();
        IntegrationErrorPublisher.publish('getAccountBalance', 503, 'Core banking call failed with HTTP 503', 'abc123');
        Test.getEventBus().deliver();
        Test.stopTest();

        List<Integration_Log__c> logs = [
            SELECT Operation__c, Status_Code__c, Message__c, Correlation_Id__c, Occurred_At__c
            FROM Integration_Log__c
        ];
        Assert.areEqual(1, logs.size());
        Assert.areEqual('getAccountBalance', logs[0].Operation__c);
        Assert.areEqual(503, logs[0].Status_Code__c.intValue());
        Assert.areEqual('abc123', logs[0].Correlation_Id__c);
        Assert.isNotNull(logs[0].Occurred_At__c);
    }

    @IsTest
    static void emptyListIsIgnored() {
        IntegrationErrorLogger.logEvents(new List<Integration_Error__e>());
        Assert.areEqual(0, [SELECT COUNT() FROM Integration_Log__c]);
    }

    @IsTest
    static void failedCalloutIsLoggedEndToEnd() {
        Test.setMock(HttpCalloutMock.class, new CoreBankingMock(new List<Object>{ 404 }));
        Test.startTest();
        try {
            new CoreBankingClient().getAccountBalance('100200300400');
            Assert.fail('Expected CoreBankingException');
        } catch (CoreBankingClient.CoreBankingException e) {
            Assert.areEqual(404, e.statusCode);
        }
        Test.stopTest(); // delivers the published event to the trigger

        Integration_Log__c log = [SELECT Status_Code__c, Correlation_Id__c FROM Integration_Log__c LIMIT 1];
        Assert.areEqual(404, log.Status_Code__c.intValue());
        Assert.isNotNull(log.Correlation_Id__c);
    }
}
