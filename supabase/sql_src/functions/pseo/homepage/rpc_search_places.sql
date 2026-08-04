CREATE OR REPLACE FUNCTION public.rpc_search_places(p_input JSONB) RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE v_query TEXT;v_locale TEXT:=COALESCE(NULLIF(p_input->>'locale',''),'en-GB');v_limit INTEGER:=COALESCE((p_input->>'limit')::int,8);BEGIN
v_query:=lower(btrim(COALESCE(p_input->>'query','')));IF char_length(v_query)<1 OR v_limit NOT BETWEEN 1 AND 20 THEN RETURN private.build_rpc_error(NULL,'ERR_INVALID_REQUEST','Invalid place search.');END IF;
RETURN jsonb_build_object('data',COALESCE((SELECT jsonb_agg(to_jsonb(result) ORDER BY result.rank_score DESC,result.name) FROM(
SELECT 'city' entity_type,city.id,city.name,city.slug code,city.slug,CASE WHEN city.slug=v_query THEN 2 ELSE 1 END rank_score FROM public.cities city WHERE lower(city.name) LIKE '%'||v_query||'%' OR city.slug LIKE '%'||v_query||'%'
UNION ALL SELECT 'airport',airport.id,airport.name,airport.iata,airport.slug,CASE WHEN lower(airport.iata)=v_query THEN 2 ELSE 1 END FROM public.airports airport WHERE lower(airport.name) LIKE '%'||v_query||'%' OR lower(airport.iata) LIKE v_query||'%'
UNION ALL SELECT 'metro_area',metro.id,metro.name,metro.code,metro.slug,CASE WHEN lower(metro.code)=v_query THEN 2 ELSE 1 END FROM public.metro_areas metro WHERE lower(metro.name) LIKE '%'||v_query||'%' OR lower(metro.code) LIKE v_query||'%'
UNION ALL SELECT alias.entity_type,alias.entity_id,alias.alias,NULL,NULL,1.5 FROM public.place_aliases alias WHERE alias.locale=v_locale AND alias.normalized_alias LIKE '%'||v_query||'%'
)result LIMIT v_limit),'[]'::jsonb),'meta',jsonb_build_object('query',v_query,'locale',v_locale,'limit',v_limit),'error',NULL);
END;$$;
REVOKE ALL ON FUNCTION public.rpc_search_places(JSONB) FROM public,anon,authenticated;GRANT EXECUTE ON FUNCTION public.rpc_search_places(JSONB) TO service_role;
