/**
 * Exposes the balance lookup to Flow (and to Agentforce as an agent action).
 * Returns a friendly error message instead of throwing, so a Flow can branch on it.
 */
public with sharing class GetAccountBalanceAction {
    public class Request {
        @InvocableVariable(required=true label='Account Number' description='Core banking account number, 6 to 17 digits')
        public String accountNumber;
    }

    public class Result {
        @InvocableVariable(label='Masked Account Number')
        public String maskedAccountNumber;
        @InvocableVariable(label='Available Balance')
        public Decimal availableBalance;
        @InvocableVariable(label='Currency')
        public String currencyCode;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Get Core Banking Account Balance'
        description='Looks up the available balance for a core banking account. Returns a masked account number.'
        category='Core Banking'
        callout=true
    )
    public static List<Result> getBalances(List<Request> requests) {
        CoreBankingClient client = new CoreBankingClient();
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                CoreBankingClient.AccountBalance balance = client.getAccountBalance(req.accountNumber);
                res.maskedAccountNumber = balance.maskedAccountNumber;
                res.availableBalance = balance.availableBalance;
                res.currencyCode = balance.currencyCode;
            } catch (IllegalArgumentException e) {
                res.errorMessage = e.getMessage();
            } catch (CoreBankingClient.CoreBankingException e) {
                res.errorMessage = 'The balance service is unavailable. Reference: ' + e.correlationId;
            }
            results.add(res);
        }
        return results;
    }
}
