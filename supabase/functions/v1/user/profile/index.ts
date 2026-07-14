import { requireUser } from '@shared/auth.ts';
import { getServiceRoleClient, getUserClient } from '@shared/supabase.ts';
import { handleProfileRequest, type ProfileRpcEnvelope } from './handler.ts';

Deno.serve((request) =>
  handleProfileRequest(request, {
    authenticate: requireUser,
    readProfile: async (jwt) => {
      const result = await getUserClient(jwt).rpc('rpc_get_user_profile');
      if (result.error) throw new Error('ERR_INTERNAL');
      return result.data as ProfileRpcEnvelope;
    },
    updateProfile: async (userId, input) => {
      const result = await getServiceRoleClient().rpc('update_user_profile', {
        p_user_id: userId,
        p_input: { display_name: input.displayName },
      });
      if (result.error) throw new Error('ERR_INTERNAL');
      return result.data as ProfileRpcEnvelope;
    },
  })
);
