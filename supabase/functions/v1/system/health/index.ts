const responseHeaders = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

Deno.serve(() => {
  return new Response(
    JSON.stringify({
      data: {
        service: 'tripways-backend',
        status: 'ok',
      },
      error: null,
    }),
    { status: 200, headers: responseHeaders },
  );
});
