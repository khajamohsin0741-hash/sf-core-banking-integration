import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from './server.mjs';

const TOKEN = 'test-token-not-a-secret';
const fixedNow = () => new Date('2026-10-01T14:30:00.000Z');
const logs = [];
let server;
let base;

before(async () => {
    server = createServer({ token: TOKEN, now: fixedNow, log: (e) => logs.push(e) });
    await new Promise((resolve) => server.listen(0, resolve));
    base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

const get = (path, headers = {}) =>
    fetch(base + path, { headers: { Authorization: `Bearer ${TOKEN}`, ...headers } });

test('health check needs no auth', async () => {
    const res = await fetch(base + '/health');
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: 'ok' });
});

test('rejects missing or wrong token', async () => {
    assert.equal((await fetch(base + '/v1/accounts/100200300400/balance')).status, 401);
    assert.equal((await get('/v1/accounts/100200300400/balance', { Authorization: 'Bearer wrong' })).status, 401);
});

test('returns balance and echoes correlation id', async () => {
    const res = await get('/v1/accounts/100200300400/balance', { 'X-Correlation-Id': 'abc123' });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('x-correlation-id'), 'abc123');
    assert.deepEqual(await res.json(), {
        accountNumber: '100200300400',
        availableBalance: 2543.18,
        ledgerBalance: 2600,
        currency: 'USD',
        asOf: '2026-10-01T14:30:00Z'
    });
});

test('unknown account returns 404', async () => {
    assert.equal((await get('/v1/accounts/999999999/balance')).status, 404);
});

test('invalid account format returns 404 without lookup', async () => {
    assert.equal((await get('/v1/accounts/12AB/balance')).status, 404);
});

test('simulate parameter forces an error status for retry demos', async () => {
    assert.equal((await get('/v1/accounts/100200300400/balance?simulate=503')).status, 503);
});

test('non-GET methods are rejected', async () => {
    const res = await fetch(base + '/v1/accounts/100200300400/balance', {
        method: 'POST',
        headers: { Authorization: `Bearer ${TOKEN}` }
    });
    assert.equal(res.status, 405);
});

test('logs mask account numbers', () => {
    const paths = logs.map((l) => l.path).join(' ');
    assert.ok(!paths.includes('100200300400'), 'full account number must not be logged');
    assert.ok(paths.includes('****0400'));
});

test('failureRate produces 503s', async () => {
    const flaky = createServer({ token: '', failureRate: 1, log: () => {} });
    await new Promise((resolve) => flaky.listen(0, resolve));
    const res = await fetch(`http://127.0.0.1:${flaky.address().port}/v1/accounts/100200300400/balance`);
    assert.equal(res.status, 503);
    flaky.close();
});
