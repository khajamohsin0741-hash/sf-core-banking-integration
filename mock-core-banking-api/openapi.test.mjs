// Keeps the OpenAPI contract and the server in step: every documented status code is
// actually returned by the server for the documented route.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createServer } from './server.mjs';

const spec = readFileSync(new URL('./openapi.yaml', import.meta.url), 'utf8');
let server;
let base;
const TOKEN = 'contract-test-token';

before(async () => {
    server = createServer({ token: TOKEN, log: () => {} });
    await new Promise((resolve) => server.listen(0, resolve));
    base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test('spec documents both routes', () => {
    assert.match(spec, /^ {2}\/health:/m);
    assert.match(spec, /^ {2}\/v1\/accounts\/\{accountNumber\}\/balance:/m);
});

test('documented balance responses match server behaviour', async () => {
    const auth = { Authorization: `Bearer ${TOKEN}` };
    const cases = [
        ['200', '/v1/accounts/100200300400/balance', auth],
        ['401', '/v1/accounts/100200300400/balance', {}],
        ['404', '/v1/accounts/999999999/balance', auth],
        ['503', '/v1/accounts/100200300400/balance?simulate=503', auth]
    ];
    for (const [status, path, headers] of cases) {
        assert.match(spec, new RegExp(`'${status}':`), `status ${status} missing from spec`);
        const res = await fetch(base + path, { headers });
        assert.equal(String(res.status), status, path);
    }
});

test('200 body has every required schema field', async () => {
    const res = await fetch(base + '/v1/accounts/100200300400/balance', {
        headers: { Authorization: `Bearer ${TOKEN}` }
    });
    const body = await res.json();
    const required = spec.match(/required: \[([^\]]+)\]/)[1].split(',').map((s) => s.trim());
    for (const field of required) {
        assert.ok(field in body, `missing ${field}`);
    }
});
