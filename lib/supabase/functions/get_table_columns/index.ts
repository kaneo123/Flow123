import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-max-age': '86400',
};

interface TableColumnsRequest {
  table_name_param: string;
}

interface ColumnInfo {
  column_name: string;
  data_type: string;
  is_nullable: string;
  column_default: string | null;
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { table_name_param } = (await req.json()) as TableColumnsRequest;

    if (!table_name_param) {
      return new Response(
        JSON.stringify({ error: 'table_name_param is required' }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
        }
      );
    }

    // Query PostgreSQL information_schema to get column information
    const { data, error } = await supabase.rpc('pg_get_columns', {
      p_table_name: table_name_param,
    });

    if (error) {
      console.error('Error fetching columns:', error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(data || []), {
      status: 200,
      headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
      }
    );
  }
});
