@IsTest
private class CoreBankingClientTest {
    private static final String ACCOUNT = '100200300400';

    @IsTest
    static void returnsParsedAndMaskedBalance() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ 200 });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CoreBankingClient.AccountBalance balance = new CoreBankingClient().getAccountBalance(ACCOUNT);
        Test.stopTest();

        Assert.areEqual('****0400', balance.maskedAccountNumber);
        Assert.areEqual(2543.18, balance.availableBalance);
        Assert.areEqual(2600.00, balance.ledgerBalance);
        Assert.areEqual('USD', balance.currencyCode);
        Assert.areEqual(Datetime.newInstanceGmt(2026, 10, 1, 14, 30, 0), balance.asOf);

        HttpRequest sent = mock.requests[0];
        Assert.areEqual('callout:Core_Banking_API/v1/accounts/' + ACCOUNT + '/balance', sent.getEndpoint());
        Assert.areEqual('GET', sent.getMethod());
        Assert.areEqual(32, sent.getHeader('X-Correlation-Id').length());
        Assert.areEqual(0, IntegrationErrorPublisher.published.size());
    }

    @IsTest
    static void retriesTransientFailureWithSameCorrelationId() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ 503, 200 });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CoreBankingClient.AccountBalance balance = new CoreBankingClient().getAccountBalance(ACCOUNT);
        Test.stopTest();

        Assert.isNotNull(balance);
        Assert.areEqual(2, mock.requests.size());
        Assert.areEqual(
            mock.requests[0].getHeader('X-Correlation-Id'),
            mock.requests[1].getHeader('X-Correlation-Id'),
            'Retries must reuse the correlation id'
        );
    }

    @IsTest
    static void retriesAfterNetworkError() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ new CalloutException('Read timed out'), 200 });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CoreBankingClient.AccountBalance balance = new CoreBankingClient().getAccountBalance(ACCOUNT);
        Test.stopTest();

        Assert.isNotNull(balance);
        Assert.areEqual(2, mock.requests.size());
    }

    @IsTest
    static void doesNotRetryClientErrorAndPublishesEvent() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ 404 });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try {
            new CoreBankingClient().getAccountBalance(ACCOUNT);
            Assert.fail('Expected CoreBankingException');
        } catch (CoreBankingClient.CoreBankingException e) {
            Assert.areEqual(404, e.statusCode);
            Assert.isNotNull(e.correlationId);
        }
        Test.stopTest();

        Assert.areEqual(1, mock.requests.size(), '4xx responses are not retried');
        Assert.areEqual(1, IntegrationErrorPublisher.published.size());
        Integration_Error__e event = IntegrationErrorPublisher.published[0];
        Assert.areEqual('getAccountBalance', event.Operation__c);
        Assert.areEqual(404, event.Status_Code__c.intValue());
    }

    @IsTest
    static void givesUpAfterMaxAttempts() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ 500, 502, 503 });
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try {
            new CoreBankingClient().getAccountBalance(ACCOUNT);
            Assert.fail('Expected CoreBankingException');
        } catch (CoreBankingClient.CoreBankingException e) {
            Assert.areEqual(503, e.statusCode);
        }
        Test.stopTest();

        Assert.areEqual(CoreBankingClient.MAX_ATTEMPTS, mock.requests.size());
        Assert.areEqual(1, IntegrationErrorPublisher.published.size());
    }

    @IsTest
    static void rejectsInvalidAccountNumberWithoutCallout() {
        CoreBankingMock mock = new CoreBankingMock(new List<Object>{ 200 });
        Test.setMock(HttpCalloutMock.class, mock);

        for (String bad : new List<String>{ null, '', '12345', 'ABC123456', '123456789012345678' }) {
            try {
                new CoreBankingClient().getAccountBalance(bad);
                Assert.fail('Expected IllegalArgumentException for ' + bad);
            } catch (IllegalArgumentException e) {
                Assert.isTrue(e.getMessage().contains('6 to 17 digits'));
            }
        }
        Assert.areEqual(0, mock.requests.size());
    }

    @IsTest
    static void unreadableResponseThrows() {
        try {
            CoreBankingClient.parseBalance('not json');
            Assert.fail('Expected CoreBankingException');
        } catch (CoreBankingClient.CoreBankingException e) {
            Assert.isTrue(e.getMessage().contains('unreadable'));
        }
    }

    @IsTest
    static void maskHandlesShortAndNullValues() {
        Assert.areEqual('****', CoreBankingClient.mask(null));
        Assert.areEqual('****', CoreBankingClient.mask('123'));
        Assert.areEqual('****6789', CoreBankingClient.mask('123456789'));
    }
}
