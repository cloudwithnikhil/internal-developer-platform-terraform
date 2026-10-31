import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/index.js';

describe('Node.js service', () => {
  it('should return a healthy response', async () => {
    const server = createApp();

    await new Promise(resolve => server.listen(0, resolve));

    try {
      const address = server.address();
      const response = await fetch(`http://127.0.0.1:${address.port}/health`);
      const body = await response.json();

      assert.equal(response.status, 200);
      assert.equal(body.status, 'ok');
      assert.equal(body.service, '${{ values.name }}');
    } finally {
      await new Promise((resolve, reject) =>
        server.close(error => error ? reject(error) : resolve())
      );
    }
  });
});
