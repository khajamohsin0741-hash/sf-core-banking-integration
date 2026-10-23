/**
 * Client for a (synthetic) core banking REST API, called through the Core_Banking_API
 * Named Credential so no endpoint or secret lives in code.
 *
 * Reliability features:
 *  - Retries transient failures (timeouts, 408, 429, 5xx) up to MAX_ATTEMPTS times.
 *  - Sends the same X-Correlation-Id on every attempt so calls can be traced end to end.
 *  - Publishes an Integration_Error__e Platform Event when a call finally fails.
 *  - Never logs request or response bodies, and masks account numbers in results.
 *
 * Apex has no sleep(), so retries are immediate. For long outages, hand off to a
 * Queueable that re-enqueues itself, or to middleware such as MuleSoft.
 */
public with sharing class CoreBankingClient {
    public static final String NAMED_CREDENTIAL = 'Core_Banking_API';
    public static final Integer MAX_ATTEMPTS = 3;
    public static final Integer TIMEOUT_MS = 10000;
    private static final Set<Integer> RETRYABLE_STATUS = new Set<Integer>{ 408, 429, 500, 502, 503, 504 };
    private static final Pattern ACCOUNT_NUMBER = Pattern.compile('^[0-9]{6,17}$');

    public class CoreBankingException extends Exception {
        public Integer statusCode;
        public String correlationId;
    }

    public class AccountBalance {
        @AuraEnabled
        public String maskedAccountNumber;
        @AuraEnabled
        public Decimal availableBalance;
        @AuraEnabled
        public Decimal ledgerBalance;
        @AuraEnabled
        public String currencyCode;
        @AuraEnabled
        public Datetime asOf;
    }

    public AccountBalance getAccountBalance(String accountNumber) {
        if (String.isBlank(accountNumber) || !ACCOUNT_NUMBER.matcher(accountNumber).matches()) {
            throw new IllegalArgumentException('Account number must be 6 to 17 digits.');
        }
        HttpResponse response = send('GET', '/v1/accounts/' + accountNumber + '/balance', 'getAccountBalance');
        return parseBalance(response.getBody());
    }

    @TestVisible
    private HttpResponse send(String method, String path, String operation) {
        String correlationId = newCorrelationId();
        HttpResponse response;
        String networkError;

        for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:' + NAMED_CREDENTIAL + path);
            request.setMethod(method);
            request.setTimeout(TIMEOUT_MS);
            request.setHeader('Accept', 'application/json');
            request.setHeader('X-Correlation-Id', correlationId);

            try {
                response = new Http().send(request);
                networkError = null;
            } catch (CalloutException e) {
                // Timeouts and connection failures are transient; try again.
                response = null;
                networkError = e.getMessage();
                continue;
            }

            Integer status = response.getStatusCode();
            if (status >= 200 && status < 300) {
                return response;
            }
            if (!RETRYABLE_STATUS.contains(status)) {
                break;
            }
        }

        Integer statusCode = response == null ? null : response.getStatusCode();
        String message = response == null
            ? 'Core banking call failed: ' + networkError
            : 'Core banking call failed with HTTP ' + statusCode;
        IntegrationErrorPublisher.publish(operation, statusCode, message, correlationId);

        CoreBankingException failure = new CoreBankingException(message);
        failure.statusCode = statusCode;
        failure.correlationId = correlationId;
        throw failure;
    }

    @TestVisible
    private static AccountBalance parseBalance(String body) {
        Map<String, Object> raw;
        try {
            raw = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new CoreBankingException('Core banking returned an unreadable response.');
        }
        AccountBalance balance = new AccountBalance();
        balance.maskedAccountNumber = mask((String) raw.get('accountNumber'));
        balance.availableBalance = toDecimal(raw.get('availableBalance'));
        balance.ledgerBalance = toDecimal(raw.get('ledgerBalance'));
        balance.currencyCode = (String) raw.get('currency');
        String asOf = (String) raw.get('asOf');
        balance.asOf = asOf == null ? null : (Datetime) JSON.deserialize('"' + asOf + '"', Datetime.class);
        return balance;
    }

    @TestVisible
    private static String mask(String accountNumber) {
        if (accountNumber == null || accountNumber.length() < 4) {
            return '****';
        }
        return '****' + accountNumber.right(4);
    }

    private static Decimal toDecimal(Object value) {
        return value == null ? null : Decimal.valueOf(String.valueOf(value));
    }

    private static String newCorrelationId() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    }
}
