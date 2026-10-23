/**
 * HttpCalloutMock that returns queued responses in order and records every request.
 */
@IsTest
public class CoreBankingMock implements HttpCalloutMock {
    public List<HttpRequest> requests = new List<HttpRequest>();
    private final List<Object> queue;

    /** Each item is an Integer status code (with a default body) or a CalloutException to throw. */
    public CoreBankingMock(List<Object> queue) {
        this.queue = queue;
    }

    public HTTPResponse respond(HTTPRequest request) {
        requests.add(request);
        Object nextItem = queue.isEmpty() ? (Object) 500 : queue.remove(0);
        if (nextItem instanceof CalloutException) {
            throw (CalloutException) nextItem;
        }
        Integer status = (Integer) nextItem;
        HttpResponse response = new HttpResponse();
        response.setStatusCode(status);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(status == 200 ? SUCCESS_BODY : '{"error":"synthetic failure"}');
        return response;
    }

    public static final String SUCCESS_BODY =
        '{"accountNumber":"100200300400","availableBalance":2543.18,"ledgerBalance":2600.00,' +
        '"currency":"USD","asOf":"2026-10-01T14:30:00Z"}';
}
