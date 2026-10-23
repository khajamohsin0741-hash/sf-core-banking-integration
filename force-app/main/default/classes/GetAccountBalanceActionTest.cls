@IsTest
private class GetAccountBalanceActionTest {
    private static GetAccountBalanceAction.Request request(String accountNumber) {
        GetAccountBalanceAction.Request req = new GetAccountBalanceAction.Request();
        req.accountNumber = accountNumber;
        return req;
    }

    @IsTest
    static void returnsBalanceForValidAccount() {
        Test.setMock(HttpCalloutMock.class, new CoreBankingMock(new List<Object>{ 200 }));

        Test.startTest();
        List<GetAccountBalanceAction.Result> results = GetAccountBalanceAction.getBalances(
            new List<GetAccountBalanceAction.Request>{ request('100200300400') }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual('****0400', results[0].maskedAccountNumber);
        Assert.areEqual(2543.18, results[0].availableBalance);
        Assert.isNull(results[0].errorMessage);
    }

    @IsTest
    static void returnsFriendlyErrors() {
        Test.setMock(HttpCalloutMock.class, new CoreBankingMock(new List<Object>{ 500, 500, 500 }));

        Test.startTest();
        List<GetAccountBalanceAction.Result> results = GetAccountBalanceAction.getBalances(
            new List<GetAccountBalanceAction.Request>{ request('bad'), request('100200300400') }
        );
        Test.stopTest();

        Assert.isTrue(results[0].errorMessage.contains('6 to 17 digits'));
        Assert.isTrue(results[1].errorMessage.startsWith('The balance service is unavailable. Reference: '));
        Assert.isNull(results[1].availableBalance);
    }
}
