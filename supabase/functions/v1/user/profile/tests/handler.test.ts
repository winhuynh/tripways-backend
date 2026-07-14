import assert from 'node:assert/strict';
import { handleProfileRequest, type ProfileDependencies } from '../handler.ts';

function dependencies(overrides: Partial<ProfileDependencies> = {}): ProfileDependencies {
  return {
    authenticate: () =>
      Promise.resolve({
        user: { id: 'verified-user' },
        jwt: 'verified.jwt',
      }),
    readProfile: () =>
      Promise.resolve({
        status: 'success',
        data: { display_name: 'Ada' },
        error: null,
        message_code: 'USER_PROFILE_READ',
      }),
    updateProfile: () =>
      Promise.resolve({
        status: 'success',
        data: { display_name: 'Grace' },
        error: null,
        message_code: 'USER_PROFILE_UPDATED',
      }),
    ...overrides,
  };
}

Deno.test('GET profile reads with the verified JWT', async () => {
  let receivedJwt: string | undefined;
  const response = await handleProfileRequest(
    new Request('https://example.test', { method: 'GET' }),
    dependencies({
      readProfile: (jwt) => {
        receivedJwt = jwt;
        return Promise.resolve({
          status: 'success',
          data: { display_name: 'Ada' },
          error: null,
          message_code: 'USER_PROFILE_READ',
        });
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.equal(receivedJwt, 'verified.jwt');
});

Deno.test('PATCH profile updates only the verified JWT user', async () => {
  let receivedUserId: string | undefined;
  let receivedName: string | undefined;
  const response = await handleProfileRequest(
    new Request('https://example.test', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ display_name: ' Grace Hopper ' }),
    }),
    dependencies({
      updateProfile: (userId, input) => {
        receivedUserId = userId;
        receivedName = input.displayName;
        return Promise.resolve({
          status: 'success',
          data: { display_name: input.displayName },
          error: null,
          message_code: 'USER_PROFILE_UPDATED',
        });
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.equal(receivedUserId, 'verified-user');
  assert.equal(receivedName, 'Grace Hopper');
});

Deno.test('profile handler normalizes RPC errors', async () => {
  const response = await handleProfileRequest(
    new Request('https://example.test', { method: 'GET' }),
    dependencies({
      readProfile: () =>
        Promise.resolve({
          status: 'error',
          data: null,
          error: { code: 'ERR_USER_PROFILE_NOT_FOUND' },
          message_code: 'ERR_USER_PROFILE_NOT_FOUND',
        }),
    }),
  );

  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), {
    data: null,
    error: { code: 'ERR_USER_PROFILE_NOT_FOUND' },
  });
});

Deno.test('PATCH profile returns 400 for an invalid request shape', async () => {
  const response = await handleProfileRequest(
    new Request('https://example.test', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ display_name: 'Ada', user_id: 'other' }),
    }),
    dependencies(),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    data: null,
    error: { code: 'ERR_PROFILE_REQUEST_INVALID' },
  });
});
