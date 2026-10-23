// Synthetic core banking API used to exercise the Salesforce client end to end.
// No dependencies: Node.js 20+ standard library only. All data is fictitious.
import http from 'node:http';
import { readFileSync } from 'node:fs';
import { randomUUID, timingSafeEqual } from 'node:crypto';

const ACCOUNT_PATTERN = /^\/v1\/accounts\/([0-9]{6,17})\/balance$/;

export function loadAccounts(path = new URL('./data/accounts.json', import.meta.url)) {
    const rows = JSON.parse(readFileSync(path, 'utf8'));
    return new Map(rows.map((row) => [row.accountNumber, row]));
}

function tokensMatch(expected, header) {
    const supplied = (header || '').replace(/^Bearer\s+/i, '');
    const a = Buffer.from(expected);
    const b = Buffer.from(supplied);
    return a.length === b.length && timingSafeEqual(a, b);
}

function mask(accountNumber) {
    return accountNumber ? '****' + accountNumber.slice(-4) : '';
}

/**
 * Options:
 *   token        - required bearer token; when empty, auth is disabled (local demos only)
 *   failureRate  - 0..1 probability of a simulated 503, for retry demos
 *   accounts     - Map of accountNumber -> balance row
 *   now          - clock function, injectable for tests
 *   log          - logger function
 */
export function createServer({
    token = '',
    failureRate = 0,
    accounts = loadAccounts(),
    now = () => new Date(),
    log = (entry) => console.log(JSON.stringify(entry)),
    random = Math.random
} = {}) {
    return http.createServer((req, res) => {
        const correlationId = req.headers['x-correlation-id'] || randomUUID();
        const url = new URL(req.url, 'http://localhost');
        const send = (status, body) => {
            res.writeHead(status, { 'Content-Type': 'application/json', 'X-Correlation-Id': correlationId });
            res.end(JSON.stringify(body));
            const match = url.pathname.match(ACCOUNT_PATTERN);
            log({ time: now().toISOString(), method: req.method, path: match ? `/v1/accounts/${mask(match[1])}/balance` : url.pathname, status, correlationId });
        };

        if (req.method === 'GET' && url.pathname === '/health') {
            return send(200, { status: 'ok' });
        }
        if (token && !tokensMatch(token, req.headers.authorization)) {
            return send(401, { error: 'unauthorized' });
        }
        if (req.method !== 'GET') {
            return send(405, { error: 'method not allowed' });
        }

        const match = url.pathname.match(ACCOUNT_PATTERN);
        if (!match) {
            return send(404, { error: 'not found' });
        }

        const simulate = url.searchParams.get('simulate');
        if (simulate && /^[45][0-9]{2}$/.test(simulate)) {
            return send(Number(simulate), { error: 'simulated failure' });
        }
        if (failureRate > 0 && random() < failureRate) {
            return send(503, { error: 'temporarily unavailable' });
        }

        const account = accounts.get(match[1]);
        if (!account) {
            return send(404, { error: 'account not found' });
        }
        return send(200, { ...account, asOf: now().toISOString().replace(/\.\d{3}Z$/, 'Z') });
    });
}

// Start only when run directly (not when imported by tests).
if (import.meta.url === `file://${process.argv[1]}`) {
    const port = Number(process.env.PORT || 8080);
    const token = process.env.MOCK_API_TOKEN || '';
    const failureRate = Number(process.env.FAILURE_RATE || 0);
    if (!token) {
        console.warn('MOCK_API_TOKEN is not set: authentication is disabled. Use only for local demos.');
    }
    createServer({ token, failureRate }).listen(port, () => {
        console.log(`Mock core banking API listening on port ${port}`);
    });
}
